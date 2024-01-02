require "sidekiq/cron/job"
require "sidekiq/cron/namespace"
require "sidekiq/cron/poller"
require "sidekiq/cron/launcher"
require "sidekiq/cron/schedule_loader"

module Sidekiq
  module Cron
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    class Configuration
      # The default namespace is used when no namespace is specified.
      attr_accessor :default_namespace

      def initialize
        @default_namespace = 'default'
      end
    end
  end
end

Sidekiq::Cron.configure
