# 1.2.0

 - Support SSL Endpoint configuration, as well as the default SNI.

# 1.1.3

 - 1.1.1 wasn't a correct fix for catching redirects during polling, this
   should work better!

# 1.1.2

 - Increase challenge file poll wait time to 60 seconds to match
   [Heroku's limit](https://devcenter.heroku.com/articles/limits).

# 1.1.1

 - Capture `OpenURI::HTTPRedirect` exceptions when polling for challenge
   filename. Heroku apps configured for zero downtime will be able to respond
   straight away to the request, but will probably respond with a redirect if
   configured with `force_ssl`. Closes issue #41.

# 1.1.0

 - Make `ACME_DOMAIN` optional by using the Heroku API to get a full list of
   configured domains for the app. Useful for apps with lots of domains.
   Configuring `ACME_DOMAIN` is still supported.

# 1.0.0

The major version bump reflects the backwards-incompatible change around how
errors are handled; `abort` vs. custom exception types.

Huge thanks to everyone that contributed to this release, either via raising
issues or submitting pull requests.

 - Raise exceptions on errors, instead of just `abort`ing. This should help
   you catch when your certificate renewal fails, before it expires completely.
   Closes issue #21 and pull request #28. Thanks @abigailmcp!

 - Wait up to 30 seconds for LetsEncrypt to verify a domain challenge. Closes
   issue #6 and pull requests #30, #25 and #7. Thanks @abigailmcp!

 - Attempt to fetch the challenge URL for up to 30 seconds before giving up.
   Closes issue #9 and pull request #28. Thanks @abigailmcp!

# 0.3.0

 - Remove some Rails-specific methods and code to allow the gem to be used
   (with some extra steps) by non-Rails applications like Sinatra. Closes issue
   #14 and pull request #15, thanks @cbetta!

# 0.2.6

 - Add more details of the error returned by LetsEncrypt when a challenge fails.
   Closes pull request #2, thanks @fjg!

# 0.2.5

 - Verify multiple domains individually, fixing support for multiple domains.
   Closes issue #1, thanks @richardvenneman!
