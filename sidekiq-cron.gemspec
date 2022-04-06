# frozen_string_literal: true

require './lib/sidekiq/cron/version'

Gem::Specification.new do |s|
  s.name = "sidekiq-cron".freeze
  s.version = Sidekiq::Cron::VERSION

  s.required_ruby_version = ">= 2.5"
  s.require_paths = ["lib"]
  s.authors = ["Ondrej Bartas"]
  s.date = "2020-04-03"
  s.description = "Enables to set jobs to be run in specified time (using CRON notation)"
  s.email = "ondrej@bartas.cz"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir.glob('lib/**/*') + Dir.glob('test/**/*') + [
    ".document",
    "Changes.md",
    "Dockerfile",
    "config.ru",
    "docker-compose.yml",
    "examples/web-cron-ui.png",
    "Gemfile",
    "LICENSE.txt",
    "Rakefile",
    "README.md",
    "sidekiq-cron.gemspec",
  ]
 
  s.homepage = "https://github.com/ondrejbartas/sidekiq-cron"
  s.licenses = ["MIT"]
  s.summary = "Sidekiq Cron helps to add repeated scheduled jobs"

  s.add_dependency("fugit", ">= 1.1")
  s.add_dependency("sidekiq", ">= 4.2.1")

  s.add_development_dependency("minitest", ">= 0")
  s.add_development_dependency("mocha", ">= 0")
  s.add_development_dependency("redis-namespace", ">= 1.5.2")
  s.add_development_dependency("rack", "~> 2.0")
  s.add_development_dependency("rack-test", "~> 1.0")
  s.add_development_dependency("rake", "~> 13.0")
  s.add_development_dependency("shoulda-context", ">= 0")
  s.add_development_dependency("simplecov", ">= 0")
end
