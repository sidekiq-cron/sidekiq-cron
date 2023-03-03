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
require 'sidekiq'
require 'sidekiq/web'
require "sidekiq/cli"
require 'sidekiq-cron'
require 'sidekiq/cron/web'

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

module ActiveJob
  class Base
    attr_accessor *%i[job_class provider_job_id queue_name arguments]

    def initialize
      yield self if block_given?
      self.provider_job_id ||= SecureRandom.hex(12)
    end

    def self.queue_name_prefix
      @queue_name_prefix
    end

    def self.queue_name_prefix=(queue_name_prefix)
      @queue_name_prefix = queue_name_prefix
    end

    def self.set(options)
      @queue = options['queue']

      self
    end

    def try(method, *args, &block)
      send method, *args, &block if respond_to? method
    end

    def self.perform_later(*args)
      new do |instance|
        instance.job_class = self.class.name
        instance.queue_name = @queue
        instance.arguments = [*args]
      end
    end
  end
end

class ActiveJobCronTestClass < ActiveJob::Base
end
