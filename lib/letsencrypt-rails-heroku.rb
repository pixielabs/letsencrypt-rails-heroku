require 'letsencrypt-rails-heroku/letsencrypt'
require 'letsencrypt-rails-heroku/middleware'

if defined?(Rails)
  require 'letsencrypt-rails-heroku/railtie'
end
