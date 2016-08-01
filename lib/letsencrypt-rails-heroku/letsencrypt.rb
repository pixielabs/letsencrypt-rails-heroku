module Letsencrypt
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  def self.challenge_configured?
    configuration.acme_challenge_filename.present? && 
      configuration.acme_challenge_filename.starts_with?("/.well-known/") &&
      configuration.acme_challenge_file_content.present?
  end

  class Configuration
    attr_accessor :heroku_token, :heroku_app, :acme_email, :acme_domain
    
    # Not settable by user; part of the gem's behaviour.
    attr_reader :acme_challenge_filename, :acme_challenge_file_content

    def initialize
      @heroku_token = ENV["HEROKU_TOKEN"]
      @heroku_app = ENV["HEROKU_APP"]
      @acme_email = ENV["ACME_EMAIL"]
      @acme_domain = ENV["ACME_DOMAIN"]
      @acme_endpoint = ENV["ACME_ENDPOINT"].presence || 'https://acme-v01.api.letsencrypt.org/'
      @acme_challenge_filename = ENV["ACME_CHALLENGE_FILENAME"]
      @acme_challenge_file_content = ENV["ACME_CHALLENGE_FILE_CONTENT"]
    end

    def valid?
      heroku_token.present? && heroku_app.present? && acme_email.present? &&
        acme_domain.present?
    end
  end
end
