module Letsencrypt
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  def self.challenge_configured?
    configuration.acme_challenge_filename && 
      configuration.acme_challenge_filename.start_with?(".well-known/") &&
      configuration.acme_challenge_file_content
  end

  def self.registered?
    configuration.acme_private_key && configuration.acme_key_id
  end

  class Configuration
    attr_accessor :heroku_token, :heroku_app, :acme_email, :acme_domain,
      :acme_directory, :ssl_type, :acme_terms_agreed
    
    # Not settable by user; part of the gem's behaviour.
    attr_reader :acme_challenge_filename, :acme_challenge_file_content,
      :acme_private_key, :acme_key_id

    def initialize
      @heroku_token = ENV["HEROKU_TOKEN"]
      @heroku_app = ENV["HEROKU_APP"]
      @acme_email = ENV["ACME_EMAIL"]
      @acme_domain = ENV["ACME_DOMAIN"]
      @acme_directory = 'https://acme-v02.api.letsencrypt.org/directory'
      @acme_terms_agreed = ENV["ACME_TERMS_AGREED"]
      @ssl_type = ENV["SSL_TYPE"] || 'sni'

      @acme_challenge_filename = ENV["ACME_CHALLENGE_FILENAME"]
      @acme_challenge_file_content = ENV["ACME_CHALLENGE_FILE_CONTENT"]

      @acme_private_key = ENV["ACME_PRIVATE_KEY"]
      @acme_key_id = ENV["ACME_KEY_ID"]
    end

    def valid?
      heroku_token && heroku_app && acme_email && acme_terms_agreed
    end
  end
end
