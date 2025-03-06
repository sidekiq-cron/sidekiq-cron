$TESTING = true
ENV['RACK_ENV'] = 'test'

require 'simplecov'

if ENV['CI']
  require 'simplecov-cobertura'
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
end

SimpleCov.start do
  add_filter 'test/'
  add_group 'Sidekiq-Cron', 'lib/'
end

require 'minitest/autorun'
require 'rack/test'
require 'mocha/minitest'
require 'active_job'
require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq/cli'
require 'sidekiq-cron'
require 'sidekiq/cron/web'
require './test/support/classes'
require './test/support/helpers'

require "rails/engine/railties"
require "sidekiq/rails"
ActiveJob::Base.queue_adapter = :sidekiq

Sidekiq.logger.level = Logger::ERROR
Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://0.0.0.0:6379' }
end

# For testing symbolize args
class Hash
  def symbolize_keys
    transform_keys { |key| key.to_sym rescue key }
  end
end
