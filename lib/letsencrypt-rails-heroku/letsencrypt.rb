module Letsencrypt
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  def self.challenge_dns_configured?
    configuration.acme_challenge_type == 'dns' &&
      configuration.cloudflare_email != nil &&
      configuration.cloudflare_api_key != nil
  end

  def self.challenge_file_configured?
    configuration.acme_challenge_type == 'file' &&
      configuration.acme_challenge_filename != nil &&
      configuration.acme_challenge_filename.start_with?(".well-known/") &&
      configuration.acme_challenge_file_content != nil
  end

  class Configuration
    attr_accessor :heroku_token, :heroku_app, :acme_email, :acme_domain,
                  :acme_endpoint, :acme_challenge_type

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
      if acme_challenge_type == 'dns'
        @cloudflare_api_key =  ENV['CLOUDFLARE_API_KEY']
        @cloudflare_email =  ENV['CLOUDFLARE_EMAIL']
      end
      if acme_challenge_type == 'file'
        @acme_challenge_filename = ENV["ACME_CHALLENGE_FILENAME"]
        @acme_challenge_file_content = ENV["ACME_CHALLENGE_FILE_CONTENT"]
      end
    end

    def valid?
      heroku_token != nil && heroku_app != nil && acme_email != nil &&
        acme_domain != nil && %w(file dns).include?(acme_challenge_type)
    end
  end
end
