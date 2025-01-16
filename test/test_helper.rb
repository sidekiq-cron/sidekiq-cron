$TESTING = true
ENV['RACK_ENV'] = 'test'

require 'simplecov'

if ENV['CI']
  require 'simplecov-cobertura'
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
end

SimpleCov.start do
  add_filter "test/"
  add_group 'Sidekiq-Cron', 'lib/'
end

require "minitest/autorun"
require "rack/test"
require 'mocha/minitest'
require 'active_job'
require 'sidekiq'
require 'sidekiq/web'
require "sidekiq/cli"
require 'sidekiq-cron'
require 'sidekiq/cron/web'

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

class CronTestClass
  include Sidekiq::Worker
  sidekiq_options retry: true

  def perform args = {}
    puts "super croned job #{args}"
  end
end

class CronTestClassWithQueue
  include Sidekiq::Worker
  sidekiq_options queue: :super, retry: false, backtrace: true

  def perform args = {}
    puts "super croned job #{args}"
  end
end

class ActiveJobCronTestClass < ::ActiveJob::Base
  def perform(*)
    nil
  end
end

class ActiveJobCronTestClassWithQueue < ::ActiveJob::Base
  queue_as :super

  def perform(*)
    nil
  end
end

def capture_logging(level:)
  original_logger = Sidekiq.logger

  logdev = StringIO.new
  logger = ::Logger.new(logdev)
  logger.level = level

  Sidekiq.configure_server { |c| c.logger = logger }

  yield

  logdev.string
ensure
  Sidekiq.configure_server do |c|
    c.logger = original_logger
  end
end
