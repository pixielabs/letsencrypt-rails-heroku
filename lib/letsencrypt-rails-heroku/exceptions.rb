module Letsencrypt
  module Error
    # LetsEncrypt encountered an issue verifying the challenge.
    class VerificationError < StandardError; end
    # LetsEncrypt encountered an issue finalizing the order.
    class FinalizationError < StandardError; end
    # Challenge URL is not available.
    class ChallengeUrlError < StandardError; end
    # Domain verification took longer than we'd like.
    class VerificationTimeoutError < StandardError; end
    # Order finalization took longer than we'd like.
    class FinalizationTimeoutError < StandardError; end
    # Error adding the certificate to Heroku.
    class HerokuCertificateError < StandardError; end
  end
end
