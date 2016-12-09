require 'domain_name'
require 'rubyflare'

module Letsencrypt
  class << self
    attr_accessor :configuration
    attr_reader :cloudflare_client
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
    if configuration.acme_challenge_type == 'dns' && challenge_dns_configured?
      @cloudflare_client = Rubyflare.connect_with(configuration.cloudflare_email, configuration.cloudflare_api_key)
      @cloudflare_client.get('user')
    end
  end

  def self.challenge_dns_configured?
    configuration.acme_challenge_type == 'dns' &&
      configuration.cloudflare_api_key != nil &&
      configuration.cloudflare_email != nil
  end

  def self.challenge_file_configured?
    configuration.acme_challenge_type == 'file' &&
      configuration.acme_challenge_filename != nil &&
      configuration.acme_challenge_filename.start_with?(".well-known/") &&
      configuration.acme_challenge_file_content != nil
  end

  def self.challenge_dns_for(domain, authorization)
    host = DomainName.new(domain)
    zone = cloudflare_client.get("zones", name: "#{host.domain}")

    challenge = authorization.dns01
    begin
      # clean existing challenge records
      print "Cleaning existing Cloudflare DNS challenge records for zone: #{host.domain}..."
      records = cloudflare_client.get("/zones/#{zone.result[:id]}/dns_records", type: 'TXT')
      records_to_delete = records.results.select { |record| record[:name] =~ /\A_acme-challenge/ && record[:type] == 'TXT' }
      records_to_delete.each { |record| cloudflare_client.delete("zones/#{zone.result[:id]}/dns_records/#{record[:id]}") }
      puts "Removed #{records_to_delete.count} existing challenge records!"

      print "Creating Cloudflare DNS record #{domain} for zone: #{host.domain}..."
      cloudflare_client.post("/zones/#{zone.result[:id]}/dns_records", # Domain name without subdomain
                             type: 'TXT',
                             name: "_acme-challenge.#{domain}",
                             content: challenge.record_content
                            )
      puts "Done!"
    rescue StandardError => e
      abort "Fail creating DNS record, reason: #{e.response}"
    end
    puts 'Sleeping for 1 minute while we wait for DNS to propagate.'
    sleep(60)
    challenge.request_verification
    print "Giving LetsEncrypt some time to verify..."
    while challenge.authorization.verify_status == 'pending'
      sleep(1)
    end
    puts "Done with status: #{challenge.verify_status}"
    challenge
  end

  class Configuration
    attr_accessor :heroku_token, :heroku_app, :acme_email, :acme_domain,
                  :acme_endpoint, :acme_challenge_type,
                  :cloudflare_email, :cloudflare_api_key

    # Not settable by user; part of the gem's behaviour.
    attr_reader :acme_challenge_filename, :acme_challenge_file_content

    def initialize
      @heroku_token = ENV["HEROKU_TOKEN"]
      @heroku_app = ENV["HEROKU_APP"]
      @acme_email = ENV["ACME_EMAIL"]
      @acme_domain = ENV["ACME_DOMAIN"]
      @acme_endpoint = (ENV["ACME_ENDPOINT"] ? ENV["ACME_ENDPOINT"] : nil) ||
                       'https://acme-v01.api.letsencrypt.org/'
      @acme_challenge_type = ENV["ACME_CHALLENGE_TYPE"]
      @cloudflare_email = ENV['CLOUDFLARE_EMAIL']
      @cloudflare_api_key = ENV['CLOUDFLARE_API_KEY']

      @acme_challenge_filename = ENV["ACME_CHALLENGE_FILENAME"]
      @acme_challenge_file_content = ENV["ACME_CHALLENGE_FILE_CONTENT"]
    end

    def valid?
      heroku_token != nil && heroku_app != nil && acme_email != nil &&
        acme_domain != nil && %w(file dns).include?(acme_challenge_type)
    end
  end
end
