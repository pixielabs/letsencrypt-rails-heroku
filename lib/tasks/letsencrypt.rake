# -*- coding: utf-8 -*-
require 'open-uri'
require 'openssl'
require 'acme-client'
require 'platform-api'

namespace :letsencrypt do

  desc 'Renew your LetsEncrypt certificate'
  task :renew => :environment do
    # Check configuration looks OK
    abort "letsencrypt-rails-heroku is configured incorrectly. Are you missing an environment variable or other configuration? You should have a heroku_token, heroku_app, acmp_email and acme_domain configured either via a `Letsencrypt.configure` block in an initializer or as environment variables." unless Letsencrypt.configuration.valid?

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

    domains = Letsencrypt.configuration.acme_domain.split(',').map(&:strip)

    domains.each do |domain|
      puts "Performing verification for #{domain}:"

      authorization = client.authorize(domain: domain)
      next if authorization.status == 'valid'

      challenge = authorization.http01

      print "Setting config vars on Heroku..."
      heroku.config_var.update(heroku_app, {
        'ACME_CHALLENGE_FILENAME' => challenge.filename,
        'ACME_CHALLENGE_FILE_CONTENT' => challenge.file_content
      })
      puts "Done!"

      # Wait for request to go through
      print "Giving config vars time to change..."
      sleep(5)
      puts "Done!"

      # Wait for app to come up
      print "Testing filename works (to bring up app)..."

      # Get the domain name from Heroku
      hostname = heroku.domain.list(heroku_app).first['hostname']
      open("http://#{hostname}/#{challenge.filename}").read
      puts "Done!"

      print "Giving LetsEncrypt some time to verify..."
      # Once you are ready to serve the confirmation request you can proceed.
      challenge.request_verification # => true

      while challenge.verify_status == 'pending'
        sleep(1)
      end
      puts "Done with status: #{challenge.verify_status}"

      unless challenge.verify_status == 'valid'
        abort "Status: #{challenge.verify_status}, Error: #{challenge.error}"
      end
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

    # First check for existing certificates:
    certificates = heroku.sni_endpoint.list(heroku_app)

    begin
      if certificates.any?
        print "Updating existing certificate #{certificates[0]['name']}..."
        heroku.sni_endpoint.update(heroku_app, certificates[0]['name'], {
          certificate_chain: certificate.fullchain_to_pem,
          private_key: certificate.request.private_key.to_pem
        })
        puts "Done!"
      else
        print "Adding new certificate..."
        heroku.sni_endpoint.create(heroku_app, {
          certificate_chain: certificate.fullchain_to_pem,
          private_key: certificate.request.private_key.to_pem
        })
        puts "Done!"
      end
    rescue Excon::Error::UnprocessableEntity => e
      warn "Error adding certificate to Heroku. Response from Heroku’s API follows:"
      abort e.response.body
    end

  end

end
