module Letsencrypt
  module Error
    # Exception raised when LetsEncrypt encounters an issue verifying the challenge.
    class VerificationError < StandardError; end
    # Exception raised when an error occurs adding the certificate to Heroku.
    class HerokuCertError < StandardError; end
    # Exception raised when challenge URL is not available.
    class ChallengeUrlError < StandardError; end
  end
end
