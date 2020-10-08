# LetsEncrypt & Rails & Heroku

### WATCH OUT! This gem is deprecated

Since this gem was created, Heroku have added support for [free automated SSL certificates for paid dynos](https://devcenter.heroku.com/articles/automated-certificate-management) (ACM). You should use ACM instead of this gem unless your situation is covered by the [known limitations](https://devcenter.heroku.com/articles/automated-certificate-management#known-limitations) of ACM, e.g. your app runs in Heroku Private Spaces. When we've had issues with ACM, we've had success with the [Expedited WAF](https://elements.heroku.com/addons/expeditedwaf) addon, and you might too.

---

[![Gem Version](https://badge.fury.io/rb/letsencrypt-rails-heroku.svg)](https://badge.fury.io/rb/letsencrypt-rails-heroku)

This gem is a complete solution for securing your Ruby on Rails application
on Heroku using their free SNI-based SSL and LetsEncrypt. It will automatically
handle renewals and keeping your certificate up to date.

With some extra steps, this gem can also be used with Sinatra. For an example
of how to do this, see the
[letsencrypt-rails-heroku-sinatra-example](https://github.com/pixielabs/letsencrypt-rails-heroku-sinatra-example)
repository.


## Requirements

 - You must be using hobby or professional dynos to use free SNI-based SSL.
   Find out more on [Heroku's documentation page about
   SSL](https://devcenter.heroku.com/articles/ssl).

 - You should have already configured your app DNS as per [Heroku's
   documentation](https://devcenter.heroku.com/articles/custom-domains).

## Installation

Add the gem to your Gemfile:

```
gem 'letsencrypt-rails-heroku', group: 'production'
```

And add it as middleware in your `config/environments/production.rb`:

```
Rails.application.configure do
  <...>

  config.middleware.use Letsencrypt::Middleware

  <...>
end
```

If you have configured your app to enforce SSL with the configuration option
`config.force_ssl = true` you will need to insert the middleware in front of
the middleware performing that enforcement instead, as LetsEncrypt do not allow
redirects on their verification requests:

```ruby
Rails.application.configure do
  # <...>
  
  config.middleware.insert_before ActionDispatch::SSL, Letsencrypt::Middleware

  # <...>
end
```

## Configuring

By default the gem will try to use the following set of configuration
variables. You must set:

 * `ACME_EMAIL`: Your email address, should be valid.
 * `ACME_TERMS_AGREED`: Existence of this environment variable represents your
   agreement to [Let's Encrypt's terms of service](https://letsencrypt.org/repository/).
 * `HEROKU_TOKEN`: An API token for this app. See below
 * `HEROKU_APP`: Name of Heroku app e.g. bottomless-cavern-7173

You can also set:

 * `ACME_DOMAIN`: Comma separated list of domains for which you want
   certificates, e.g. `example.com,www.example.com`. Your Heroku app should be
   configured to answer to all these domains, because Let's Encrypt will make a
   request to verify ownership.

   If you leave this blank, the gem will try and use the Heroku API to get a 
   list of configured domains for your app, and verify all of them.
 * `SSL_TYPE`: Optional: One of `sni` or `endpoint`, defaults to `sni`.
   `endpoint` requires your app to have an
   [SSL endpoint addon](https://elements.heroku.com/addons/ssl) configured.

The gem itself will temporarily create additional environment variables during
the challenge / validation process:

 * `ACME_CHALLENGE_FILENAME`: The path of the file LetsEncrypt will request.
 * `ACME_CHALLENGE_FILE_CONTENT`: The content of that challenge file.

It will also create two permanent environment variables after the first run:

 * `ACME_PRIVATE_KEY`: Private key used to create requests for certificates.
 * `ACME_KEY_ID`: Key ID assigned to your private key by Let's Encrypt.

If you remove these, a new account will be created and new environment
variables will be set.

## Creating a Heroku token

Use the `heroku-oauth` toolbelt plugin to generate an access token suitable
for accessing the Heroku API to update the certificates. From within your
project directory:

```
> heroku plugins:install heroku-cli-oauth
> heroku authorizations:create -d "LetsEncrypt"
Created OAuth authorization.
  ID:          <heroku-client-id>
  Description: LetsEncrypt
  Scope:       global
  Token:       <heroku-token>
```

Use the output of that to set the token (`HEROKU_TOKEN`).

## Using for the first time

After deploying, run `heroku run rake letsencrypt:renew`. Ensure that the
output looks good:

```
$ heroku run rake letsencrypt:renew
Running rake letsencrypt:renew on ⬢ yourapp... ⣷ connecting, run.1234
Creating account key...Done!
Registering with LetsEncrypt...Done!
Setting config vars on Heroku...Done!
Giving config vars time to change...Done!
Testing filename works (to bring up app)...done!
Adding new certificate...Done!
$ 
```

If this is the first time you have used an SNI-based SSL certificate on your
app, you may need to alter your DNS configuration as per
[Heroku's instructions](https://devcenter.heroku.com/articles/ssl-beta#change-your-dns-for-all-domains-on-your-app).

You can see these details by typing `heroku domains`.

## Adding a scheduled task

You should add a scheduled task on Heroku to renew the certificate. If you 
are unfamiliar with how to do this, take a look at [Heroku's documentation
on their scheduler addon](https://devcenter.heroku.com/articles/scheduler).

The scheduled task should be configured to run `rake letsencrypt:renew` as
often as you want to renew your certificate. Letsencrypt certificates are valid
for 90 days, but there's no harm renewing them more frequently than that.

Heroku Scheduler only lets you run a task as infrequently as once a day, but
you don't want to renew your SSL certificate every day (you will hit
[the rate limit](https://letsencrypt.org/docs/rate-limits/)). You can make it
run less frequently using a shell control statement. For example to renew your
certificate on the 1st day of every month:

```
if [ "$(date +%d)" = 01 ]; then bundle exec rake letsencrypt:renew; fi
```

Source: [blog.dbrgn.ch](https://blog.dbrgn.ch/2013/10/4/heroku-schedule-weekly-monthly-tasks/)

## Security considerations

Suggestions and pull requests are welcome in improving the situation with the
following security considerations:

 - When configuring this gem you must add a non-expiring Heroku API token into
   your application environment. Your collaborators could use this token to
   impersonate the account it was created with when accessing the Heroku API.
   This is important if your account has access to other apps that your
   collaborators don’t. Additionally, if your application environment was
   leaked this would give the attacker access to the Heroku API as your user
   account. 
   [More information about Heroku’s API and oAuth](https://devcenter.heroku.com/articles/oauth#direct-authorization).

   You should create the API token from a suitably locked-down account.

 - This gem uses two environment variables (`ACME_CHALLENGE_FILENAME` and
   `ACME_CHALLENGE_FILE_CONTENT`) to construct routes and responses in your
   app. These environment variables could be manipulated to spoof URLs on your
   application.

   The gem performs some cursory checks to make sure the filename is roughly
   what is expected to try and mitigate this.
   
## Troubleshooting

### Common name invalid errors (security certificate is from *.herokuapp.com)

Your domain is still configured as a CNAME or ALIAS to
`your-app.herokuapp.com`. Check the output of `heroku domains` matches your DNS
configuration. When you add an SNI cert to an app for the first time
[the DNS target changes](https://devcenter.heroku.com/articles/custom-domains#view-existing-domains).

## To-do list

- Persist account key, or at least give the option of using an existing one, so
  we don’t register with LetsEncrypt over and over.

- Provide instructions for running the gem decoupled from the app it is
  securing, for the paranoid.

## Contributing

- Check out the latest master to make sure the feature hasn't been implemented
  or the bug hasn't been fixed yet.
- Check out the issue tracker to make sure someone already hasn't requested it
  and/or contributed it.
- Fork the project.
- Start a feature/bugfix branch.
- Commit and push until you are happy with your contribution.
- Make sure to add tests for it. This is important so I don't break it in a
  future version unintentionally.
- Please try not to mess with the Rakefile, version, or history. If you want to
  have your own version, or is otherwise necessary, that is fine, but please
  isolate to its own commit so I can cherry-pick around it.
  
### Generating a new release

1. Bump the version: `rake version:bump:{major,minor,patch}`.
2. Update `CHANGELOG.md` & commit.
3. Use `rake release` to regenerate gemspec, push a tag to git, and push a new
   `.gem` to rubygems.org.
