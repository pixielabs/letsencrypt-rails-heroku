module LetsEncrypt
  module VerifyWith
    def http(heroku, heroku_app, challenge)
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
    end

    def dns(auth)
      challenge = auth.dns
      # Technically this could be something other than TXT I think, but acme-client
      # only supports TXT, so I've only supported that here as well.
      already_exists = false
      Resolv::DNS.open do |dns|
        ress = dns.getresources challenge.record_name + "." + auth.domain, Resolv::DNS::Resource::IN::TXT
        ress.each do |r|
          r.strings.each do |s|
            if s == challenge.record_content
              already_exists = true
              break
            end
          end
          break if already_exists
        end
      end
      if already_exists
        { success: true }
      else
        { success: false,
          records: { domain: auth.domain,
                     record: { name: challenge.record_name,
                               type: challenge.record_type,
                               content: challenge.record_content } } }
      end
    end
  end
end