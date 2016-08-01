module Letsencrypt
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      if Letsencrypt.challenge_configured? && env["PATH_INFO"] == "/#{Letsencrypt.configuration.acme_challenge_filename}"
        return [200, {"Content-Type" => "text/plain"}, [Letsencrypt.configuration.acme_challenge_file_content]]
      end

      @app.call(env)
    end

  end
end
