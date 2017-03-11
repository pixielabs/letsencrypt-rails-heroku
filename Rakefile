# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'juwelier'
Juwelier::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "letsencrypt-rails-heroku"
  gem.homepage = "https://github.com/pixielabs/letsencrypt-rails-heroku"
  gem.license = "MIT"
  gem.summary = %Q{Automatic LetsEncrypt certificates in your Rails app on Heroku}
  gem.description = %Q{This gem automatically handles creation, renewal, and applying SSL certificates from LetsEncrypt to your Heroku account.}
  gem.email = "team@pixielabs.io"
  gem.authors = ["Pixie Labs", "David Somers", "Abigail McPhillips"]

  # dependencies defined in Gemfile
end
Juwelier::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

desc "Code coverage detail"
task :simplecov do
  ENV['COVERAGE'] = "true"
  Rake::Task['test'].execute
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "letsencrypt-rails-heroku #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
