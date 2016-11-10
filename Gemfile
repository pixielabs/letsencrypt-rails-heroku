source "https://rubygems.org"

gem 'acme-client', '~> 0.4.1'
# SNI endpoints not supported yet:
# <https://github.com/heroku/platform-api/issues/49>
gem 'platform-api', github: 'jalada/platform-api', branch: 'master'

# ACME Challenge using DNS
gem 'rubyflare'
gem 'domain_name'

group :development do
  gem "shoulda", ">= 0"
  gem "rdoc", "~> 3.12"
  gem "bundler", "~> 1.0"
  gem "juwelier", "~> 2.1.0"
  gem "simplecov", ">= 0"
end
