require 'open-uri'
require 'openssl'
require 'acme-client'
require 'platform-api'

namespace :letsencrypt do

  desc 'Renew your LetsEncrypt certificate'
  task :renew do
    # Check configuration looks OK
    abort "letsencrypt-rails-heroku is configured incorrectly. Are you missing an environment variable or other configuration? You should have heroku_token, heroku_app, acme_email and acme_terms_agreed configured either via a `Letsencrypt.configure` block in an initializer or as environment variables." unless Letsencrypt.configuration.valid?

    # Set up Heroku client
    heroku = PlatformAPI.connect_oauth Letsencrypt.configuration.heroku_token
    heroku_app = Letsencrypt.configuration.heroku_app

    if Letsencrypt.registered?
      puts "Using existing registration details"
      private_key = OpenSSL::PKey::RSA.new(Letsencrypt.configuration.acme_private_key)
      key_id = Letsencrypt.configuration.acme_key_id
    else
      # Create a private key
      print "Creating account key..."
      private_key = OpenSSL::PKey::RSA.new(4096)
      puts "Done!"

      client = Acme::Client.new(private_key: private_key,
                                directory: Letsencrypt.configuration.acme_directory,
                                connection_options: { 
                                  request: { 
                                    open_timeout: 5,
                                    timeout: 5
                                  }
                                })

      print "Registering with LetsEncrypt..."
      account = client.new_account(contact: "mailto:#{Letsencrypt.configuration.acme_email}",
                                   terms_of_service_agreed: true)

      key_id = account.kid
      puts "Done!"
      print "Saving account details as configuration variables..."
      heroku.config_var.update(heroku_app,
                               'ACME_PRIVATE_KEY' => private_key.to_pem,
                               'ACME_KEY_ID' => account.kid)
      puts "Done!"
    end

    # Make a new Acme::Client with whichever private_key & key_id we ended up with.
    client = Acme::Client.new(private_key: private_key,
                              directory: Letsencrypt.configuration.acme_directory,
                              kid: key_id)

    domains = []
    if Letsencrypt.configuration.acme_domain
      puts "Using ACME_DOMAIN configuration variable..."
      domains = Letsencrypt.configuration.acme_domain.split(',').map(&:strip)
    else
      domains = heroku.domain.list(heroku_app).map{|domain| domain['hostname']}
      puts "Using #{domains.length} configured Heroku domain(s) for this app..."
    end

    order = client.new_order(identifiers: domains)

    order.authorizations.each do |authorization|
      puts "Performing verification for #{authorization.domain}:"

      challenge = authorization.http
      
      raise Letsencrypt::Error::NoHTTPChallengeError, "No HTTP challenge was given by Let's Encrypt for #{authorization.domain}, and letsencrypt-rails-heroku does not currently support other challenge types." unless challenge

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
      rescue OpenSSL::SSL::SSLError, OpenURI::HTTPError, RuntimeError => e
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
      challenge.request_validation

      start_time = Time.now
      while challenge.status == 'pending'
        if Time.now - start_time >= 30
          failure_message = "Failed - timed out waiting for challenge verification."
          raise Letsencrypt::Error::VerificationTimeoutError, failure_message
        end
        sleep(2)
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
    csr_private_key = OpenSSL::PKey::RSA.new 4096
    csr = Acme::Client::CertificateRequest.new(names: domains,
                                               private_key: csr_private_key)

    print "Asking LetsEncrypt to finalize our certificate order..."
    # Get certificate
    order.finalize(csr: csr)

    # Wait for order to process
    start_time = Time.now
    while order.status == 'processing'
      if Time.now - start_time >= 30
        failure_message = "Failed - timed out waiting for order finalization"
        raise Letsencrypt::Error::FinalizationTimeoutError, failure_message
      end
      sleep(2)
      order.reload
    end

    puts "Done!"

    unless order.status == 'valid'
      failure_message = "Problem finalizing order - status: #{order.status}"
      raise Letsencrypt::Error::FinalizationError, failure_message
    end

    certificate = order.certificate # => PEM-formatted certificate

    # Send certificates to Heroku via API

    endpoint = case Letsencrypt.configuration.ssl_type
               when 'sni'
                 heroku.sni_endpoint
               when 'endpoint'
                 heroku.ssl_endpoint
               end

    certificate_info = {
      certificate_chain: certificate,
      private_key: csr_private_key.to_pem
    }

    # Fetch existing certificate from Heroku (if any). We just use the first
    # one; if someone has more than one, they're probably not actually using
    # this gem. Could also be an error?
    existing_certificate = endpoint.list(heroku_app)[0]

    begin
      if existing_certificate
        print "Updating existing certificate #{existing_certificate['name']}..."
        endpoint.update(heroku_app, existing_certificate['name'], certificate_info)
        puts "Done!"
      else
        print "Adding new certificate..."
        endpoint.create(heroku_app, certificate_info)
        puts "Done!"
      end
    rescue Excon::Error::UnprocessableEntity => e
      warn "Error adding certificate to Heroku. Response from Heroku’s API follows:"
      raise Letsencrypt::Error::HerokuCertificateError, e.response.body
    end

  end

end
