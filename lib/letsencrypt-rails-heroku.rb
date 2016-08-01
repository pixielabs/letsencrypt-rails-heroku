require 'letsencrypt-rails-heroku/letsencrypt'

if defined?(Rails)
  require 'letsencrypt-rails-heroku/railtie'
  require 'letsencrypt-rails-heroku/engine'
end
