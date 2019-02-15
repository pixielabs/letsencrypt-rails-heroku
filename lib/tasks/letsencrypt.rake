require 'open-uri'
require 'openssl'
require 'acme-client'
require 'platform-api'
require 'resolv'

namespace :letsencrypt do

  desc 'Renew your LetsEncrypt certificate'
  task :renew do
    # Check configuration looks OK
    abort "letsencrypt-rails-heroku is configured incorrectly. Are you missing an environment variable or other configuration? You should have a heroku_token, heroku_app and acme_email configured either via a `Letsencrypt.configure` block in an initializer or as environment variables." unless Letsencrypt.configuration.valid?

    # Set up Heroku client
    heroku = PlatformAPI.connect_oauth Letsencrypt.configuration.heroku_token
    heroku_app = Letsencrypt.configuration.heroku_app

    if Letsencrypt.configuration.acme_key.blank?
      # Create a private key
      print "Creating account key..."
      private_key = OpenSSL::PKey::RSA.new(4096)
      puts "Done!"
    else
      print "Using existing private key from acme-account-key.pem"
      private_key = OpenSSL::PKey::RSA.new(Letsencrypt.configuration.acme_key)
    end

    if Letsencrypt.configuration.acme_kid.blank?
      client = Acme::Client.new(private_key: private_key, directory: Letsencrypt.configuration.acme_directory)
      print "Registering with LetsEncrypt..."
      registration = client.new_account(contact: "mailto:#{Letsencrypt.configuration.acme_email}",
                                        terms_of_service_agreed: true)
      heroku.config_var.update(heroku_app, {
          'ACME_KEY' => private_key.to_pem,
          'ACME_KID' => registration.kid
      })
      puts "Done! Use the following values for the key variables in future:",
           "ACME_KEY: #{private_key.to_pem}",
           ("ACME_KID: #{registration.kid}" if Letsencrypt.configuration.acme_kid.blank?)
    else
      print "Using existing LetsEncrypt registration"
      client = Acme::Client.new(private_key: private_key,
                                directory: Letsencrypt.configuration.acme_directory,
                                kid: Letsencrypt.configuration.acme_kid)
    end

    if Letsencrypt.configuration.acme_domain
      puts "Using ACME_DOMAIN configuration variable..."
      domains = Letsencrypt.configuration.acme_domain.split(',').map(&:strip)
    else
      domains = heroku.domain.list(heroku_app).map{|domain| domain['hostname']}
      puts "Using #{domains.length} configured Heroku domain(s) for this app..."
    end

    puts "Placing order..."
    order = client.new_order(identifiers: domains)

    using_dns = false
    dns_records_to_change = []

    order.authorizations.each do |auth|
      challenge = auth.http
      # Always prefer HTTP challenge to DNS challenge; only use DNS challenge where
      # HTTP challenge isn't possible (ex: wildcard domains), or where explicitly
      # requested in the environment
      if challenge and !(Letsencrypt.configuration.force_dns)
        dns = Letsencrypt::VerifyWith.http heroku, heroku_app, challenge
      else
        puts "HTTP challenge unavailable, falling back to DNS challenge"
        using_dns = true
        dns = Letsencrypt::VerifyWith.dns auth
        dns_records_to_change.push(dns[:records]) unless dns[:success]
      end

      if using_dns && !dns_records_to_change.blank?
        puts "---", "DNS records are currently missing. Please add the following DNS records and retry:"
        dns_records_to_change.each do |record|
          puts "----", "Domain: #{record[:domain]}", "Record name: #{record[:record][:name]}",
               "Record type: #{record[:record][:type]}", "Record content: #{record[:record][:content]}", "----"
        end
        puts "---"
        raise Letsencrypt::Error::DNSValidationError
      end

      print "Giving LetsEncrypt some time to verify..."
      # Once you are ready to serve the confirmation request you can proceed.
      challenge.request_validation # => true
      challenge.status # => 'pending'

      start_time = Time.now

      while challenge.status == 'pending'
        if Time.now - start_time >= 30
          failure_message = "Failed - timed out waiting for challenge verification."
          raise Letsencrypt::Error::VerificationTimeoutError, failure_message
        end
        sleep(3)
        challenge.reload
      end

      puts "Done!"

      unless challenge.status == 'valid'
        puts "Problem verifying challenge."
        failure_message = "Status: #{challenge.status}, Error: #{challenge.error}"
        raise Letsencrypt::Error::VerificationError, failure_message
      end

      puts ""
    end

    # Unset temporary config vars. We don't care about waiting for this to
    # restart
    heroku.config_var.update(heroku_app, {
      'ACME_CHALLENGE_FILENAME' => nil,
      'ACME_CHALLENGE_FILE_CONTENT' => nil
    })

    # Create CSR
    csr_private_key = OpenSSL::PKey::RSA.new(4096)
    csr = Acme::Client::CertificateRequest.new(names: domains, private_key: csr_private_key)
    order.finalize(csr: csr)
    sleep(1) while order.status == 'processing'

    # Get certificate
    certificate = order.certificate # => PEM-formatted certificate

    # Send certificates to Heroku via API

    endpoint = case Letsencrypt.configuration.ssl_type
               when 'sni'
                 heroku.sni_endpoint
               when 'endpoint'
                 heroku.ssl_endpoint
               end

    # First check for existing certificates:
    certificates = endpoint.list(heroku_app)

    certinfo = {
        certificate_chain: certificate,
        private_key: csr_private_key.to_pem
    }

    begin
      if certificates.any?
        print "Updating existing certificate #{certificates[0]['name']}..."
        endpoint.update(heroku_app, certificates[0]['name'], certinfo)
        puts "Done!"
      else
        print "Adding new certificate..."
        endpoint.create(heroku_app, certinfo)
        puts "Done!"
      end
    rescue Excon::Error::UnprocessableEntity => e
      warn "Error adding certificate to Heroku. Response from Heroku’s API follows:"
      raise Letsencrypt::Error::HerokuCertificateError, e.response.body
    end

  end

end
