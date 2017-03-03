require 'open-uri'
require 'openssl'
require 'acme-client'
require 'platform-api'

namespace :letsencrypt do

  desc 'Renew your LetsEncrypt certificate'
  task :renew do
    # Check configuration looks OK
    abort "letsencrypt-rails-heroku is configured incorrectly. Are you missing an environment variable or other configuration? You should have a heroku_token, heroku_app and acme_email configured either via a `Letsencrypt.configure` block in an initializer or as environment variables." unless Letsencrypt.configuration.valid?

    # Set up Heroku client
    heroku = PlatformAPI.connect_oauth Letsencrypt.configuration.heroku_token
    heroku_app = Letsencrypt.configuration.heroku_app

    # Create a private key
    print "Creating account key..."
    private_key = OpenSSL::PKey::RSA.new(4096)
    puts "Done!"

    client = Acme::Client.new(private_key: private_key, endpoint: Letsencrypt.configuration.acme_endpoint, connection_options: { request: { open_timeout: 5, timeout: 5 } })

    print "Registering with LetsEncrypt..."
    registration = client.register(contact: "mailto:#{Letsencrypt.configuration.acme_email}")

    registration.agree_terms
    puts "Done!"

    domains = []
    if Letsencrypt.configuration.acme_domain
      puts "Using ACME_DOMAIN configuration variable..."
      domains = Letsencrypt.configuration.acme_domain.split(',').map(&:strip)
    else
      domains = heroku.domain.list(heroku_app).map{|domain| domain['hostname']}
      puts "Using #{domains.length} configured Heroku domain(s) for this app..."
    end

    domains.each do |domain|
      puts "Performing verification for #{domain}:"

      authorization = client.authorize(domain: domain)
      challenge = authorization.http01

      print "Setting config vars on Heroku..."
      heroku.config_var.update(heroku_app, {
        'ACME_CHALLENGE_FILENAME' => challenge.filename,
        'ACME_CHALLENGE_FILE_CONTENT' => challenge.file_content
      })
      puts "Done!"

      # Wait for app to come up
      print "Testing filename works (to bring up app)..."

      # Get the domain name from Heroku
      hostname = heroku.domain.list(heroku_app).first['hostname']
      
      # Wait at least a little bit, otherwise the first request will almost always fail.
      sleep(2)

      start_time = Time.now

      begin
        open("http://#{hostname}/#{challenge.filename}").read
      rescue OpenURI::HTTPError, RuntimeError => e
        raise e if e.is_a?(RuntimeError) && !e.message.include?("redirection forbidden")
        if Time.now - start_time <= 60
          puts "Error fetching challenge, retrying... #{e.message}"
          sleep(5)
          retry
        else
          failure_message = "Error waiting for response from http://#{hostname}/#{challenge.filename}, Error: #{e.message}"
          raise Letsencrypt::Error::ChallengeUrlError, failure_message
        end
      end

      puts "Done!"

      print "Giving LetsEncrypt some time to verify..."
      # Once you are ready to serve the confirmation request you can proceed.
      challenge.request_verification # => true
      challenge.verify_status # => 'pending'

      start_time = Time.now

      while challenge.verify_status == 'pending'
        if Time.now - start_time >= 30
          failure_message = "Failed - timed out waiting for challenge verification."
          raise Letsencrypt::Error::VerificationTimeoutError, failure_message
        end
        sleep(3)
      end

      puts "Done!"

      unless challenge.verify_status == 'valid'
        puts "Problem verifying challenge."
        failure_message = "Status: #{challenge.verify_status}, Error: #{challenge.error}"
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
    csr = Acme::Client::CertificateRequest.new(names: domains)

    # Get certificate
    certificate = client.new_certificate(csr) # => #<Acme::Client::Certificate ....>

    # Send certificates to Heroku via API

    endpoint = case Letsencrypt.configuration.ssl_type
               when 'sni'
                 heroku.sni_endpoint
               when 'endpoint'
                 heroku.ssl_endpoint
               end

    # First check for existing certificates:
    certificates = endpoint.list(heroku_app)

    begin
      if certificates.any?
        print "Updating existing certificate #{certificates[0]['name']}..."
        endpoint.update(heroku_app, certificates[0]['name'], {
          certificate_chain: certificate.fullchain_to_pem,
          private_key: certificate.request.private_key.to_pem
        })
        puts "Done!"
      else
        print "Adding new certificate..."
        endpoint.create(heroku_app, {
          certificate_chain: certificate.fullchain_to_pem,
          private_key: certificate.request.private_key.to_pem
        })
        puts "Done!"
      end
    rescue Excon::Error::UnprocessableEntity => e
      warn "Error adding certificate to Heroku. Response from Heroku’s API follows:"
      raise Letsencrypt::Error::HerokuCertificateError, e.response.body
    end

  end

end
