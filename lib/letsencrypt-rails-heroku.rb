require 'letsencrypt-rails-heroku/letsencrypt'
require 'letsencrypt-rails-heroku/middleware'
require 'letsencrypt-rails-heroku/exceptions'
require 'letsencrypt-rails-heroku/verifiers'

if defined?(Rails)
  require 'letsencrypt-rails-heroku/railtie'
end
