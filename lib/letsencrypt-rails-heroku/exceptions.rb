module Letsencrypt
  module Error
    # Exception raised when LetsEncrypt encounters an issue verifying the challenge.
    class VerificationError < StandardError; end
    # Exception raised when challenge URL is not available.
    class ChallengeUrlError < StandardError; end
    # Exception raised on timeout of challenge verification.
    class VerificationTimeoutError < StandardError; end
    # Exception raised when an error occurs adding the certificate to Heroku.
    class HerokuCertificateError < StandardError; end
  end
end
