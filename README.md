# LetsEncrypt & Rails & Heroku

[![Gem Version](https://badge.fury.io/rb/letsencrypt-rails-heroku.svg)](https://badge.fury.io/rb/letsencrypt-rails-heroku)

This gem is a complete solution for securing your Ruby on Rails application
on Heroku using their free SNI-based SSL and LetsEncrypt. It will automatically
handle renewals and keeping your certificate up to date.


## Requirements

 - Whilst it is in beta, you must use the labs feature to enable Heroku's free
   SSL offering:

   ```
   heroku labs:enable http-sni
   ```

 - You must be using hobby or professional dynos to use free SNI-based SSL.

 - You should have already configured your app DNS as per [Heroku's
   documentation](https://devcenter.heroku.com/articles/custom-domains).

## Installation

Add the gem to your Gemfile:

```
# Until the API calls are out of beta, you must manually specify my fork
# of the Heroku API gem:
gem 'platform-api', github: 'jalada/platform-api', branch: 'master'

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

## Configuring

By default the gem will try to use the following set of configuration variables,
which you should set.

 * `ACME_DOMAIN`: Comma separated list of domains for which you want
   certificates, e.g. `example.com,www.example.com`. Your Heroku app should be
   configured to answer to all these domains, because LetsEncrypt will make a
   request to verify ownership.
 * `ACME_EMAIL`: Your email address, should be valid.
 * `HEROKU_TOKEN`: An API token for this app. See below
 * `HEROKU_APP`: Name of Heroku app e.g. bottomless-cavern-7173

The gem itself will temporarily create additional environment variables during
the challenge / validation process:

 * `ACME_CHALLENGE_FILENAME`: The path of the file LetsEncrypt will request.
 * `ACME_CHALLENGE_FILE_CONTENT`: The content of that challenge file.

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

You should add a scheduled task on Heroku to renew the certificate. The
scheduled task should be configured to run `rake letsencrypt:renew` as often
as you want to renew your certificate. Letsencrypt certificates are valid for
90 days, but there's no harm renewing them more frequently than that.

Heroku Scheduler only lets you run a task as infrequently as once a day, but
you don't want to renew your SSL certificate every day (you will hit
[the rate limit](https://letsencrypt.org/docs/rate-limits/)). You can make it
run less frequently using a shell control statement. For example to renew your
certificate on the 1st day of every month:

```
if [ "$(date +%d)" = 01 ]; then rake letsencrypt:renew; fi
```

Source: [blog.dbrgn.ch](https://blog.dbrgn.ch/2013/10/4/heroku-schedule-weekly-monthly-tasks/)

## Security considerations

Suggestions and pull requests are welcome in improving the situation with the
following security considerations:

 - When configuring this gem you must add a non-expiring Heroku API token
   into your application environment. Your collaborators could use this
   token to impersonate the account it was created with when accessing
   the Heroku API. This is important if your account has access to other apps
   that your collaborators don’t. Additionally, if your application environment was
   leaked this would give the attacker access to the Heroku API as your user account. 
   [More information about Heroku’s API and oAuth](https://devcenter.heroku.com/articles/oauth#direct-authorization).

   You should create the API token from a suitably locked-down account.

 - This gem uses two environment variables (`ACME_CHALLENGE_FILENAME` and
   `ACME_CHALLENGE_FILE_CONTENT`) to construct routes and responses in your
   app. These environment variables could be manipulated to spoof URLs on your
   application.

   The gem performs some cursory checks to make sure the filename is roughly
   what is expected to try and mitigate this.

## To-do list

- Persist account key, or at least give the option of using an existing one, so
  we don’t register with LetsEncrypt over and over.

- Stop using a fork of the `platform-api` gem once it supports the SNI endpoint
  API calls. [See issue #49 of the platform-api gem](https://github.com/heroku/platform-api/issues/49).

- Provide instructions for running the gem decoupled from the app it is 
  securing, for the paranoid.

- Support non-SNI Heroku SSL too.

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
