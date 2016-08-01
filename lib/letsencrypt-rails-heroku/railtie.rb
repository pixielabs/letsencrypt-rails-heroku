class LetsencryptRailsHerokuRailtie < Rails::Railtie
  config.before_configuration do
    Letsencrypt.configure
  end
end
