class LetsencryptRailsHerokuRailtie < Rails::Railtie
  config.before_configuration do
    Letsencrypt.configure
  end

  initializer "letsencrypt_rails_heroku.configure_rails_initialization" do |app|
    if app.config.force_ssl
      app.middleware.insert_before ActionDispatch::SSL, Letsencrypt::Middleware
    else
      app.middleware.use Letsencrypt::Middleware
    end
  end

  rake_tasks do
    load 'tasks/letsencrypt.rake'
  end
end
