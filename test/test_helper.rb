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

# Workaround: We need to define this class, so the actual adapter can remove the constant
# See: https://github.com/sidekiq/sidekiq/pull/6474
module ActiveJob
  module QueueAdapters
    class SidekiqAdapter; end
  end
end

# In https://github.com/sidekiq/sidekiq/commit/7e27a3fbfd3163fd58a17fef8ad6594b92bb3a6c
# (released in Sidekiq v7.3.3+) Sidekiq introduced the module `Sidekiq::ActiveJob`.
# Any reference to `ActiveJob` within `Sidekiq::Cron` therefore does not
# get resolved to `::ActiveJob`, but to `::Sidekiq::ActiveJob`.
#
# By loading the adapter code here, we ensure that tests break unless `::ActiveJob`
# is used explicitly.
require 'active_job/queue_adapters/sidekiq_adapter' if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("7.3.3")

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
    attr_accessor *%i[job_class provider_job_id arguments]

    def initialize
      yield self if block_given?
      self.provider_job_id ||= SecureRandom.hex(12)
    end

    def self.queue_name
      @queue_name || "default"
    end

    def self.queue_as(name)
      @queue_name = name
    end

    def self.queue_name_prefix
      @queue_name_prefix
    end

    def self.queue_name_prefix=(queue_name_prefix)
      @queue_name_prefix = queue_name_prefix
    end

    def self.set(options)
      @queue_name = options['queue'] || queue_name

      self
    end

    def try(method, *args, &block)
      send method, *args, &block if respond_to? method
    end

    def self.perform_later(*args)
      new do |instance|
        instance.job_class = self.class.name
        instance.queue_name = self.class.queue_name
        instance.arguments = [*args]
      end
    end
  end
end

class ActiveJobCronTestClass < ::ActiveJob::Base
end

class ActiveJobCronTestClassWithQueue < ::ActiveJob::Base
  queue_as :super
end
