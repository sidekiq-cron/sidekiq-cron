# frozen_string_literal: true

require './lib/sidekiq/cron/version'

Gem::Specification.new do |s|
  s.name = "sidekiq-cron"
  s.version = Sidekiq::Cron::VERSION
  s.summary = "Scheduler/Cron for Sidekiq jobs"
  s.description = "Enables to set jobs to be run in specified time (using CRON notation or natural language)"
  s.homepage = "https://github.com/ondrejbartas/sidekiq-cron"
  s.authors = ["Ondrej Bartas"]
  s.email = "ondrej@bartas.cz"
  s.licenses = ["MIT"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir.glob('lib/**/*') + Dir.glob('test/**/*') + [
    "CHANGELOG.md",
    "Gemfile",
    "LICENSE.txt",
    "Rakefile",
    "README.md",
    "sidekiq-cron.gemspec",
  ]

  s.required_ruby_version = ">= 2.6"

  s.add_dependency("fugit", "~> 1")
  s.add_dependency("sidekiq", ">= 4.2.1")

  s.add_development_dependency("minitest", "~> 5.15")
  s.add_development_dependency("mocha", "~> 1.14")
  s.add_development_dependency("redis-namespace", "~> 1.8")
  s.add_development_dependency("rack", "~> 2.2")
  s.add_development_dependency("rack-test", "~> 1.1")
  s.add_development_dependency("rake", "~> 13.0")
  s.add_development_dependency("simplecov", "~> 0.21")
end
