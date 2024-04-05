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
        @strict_cron_parsing = false
      end

      # Throws an error when a natural language cron string would get
      # parsed into multiple cron lines. By default the `fugit` gem is
      # permissive when parsing natural language cron strings. Only the first
      # cron line is used in that case and all other ones are ignored.
      def strict_cron_parsing!
        @strict_cron_parsing = true
      end

      def strict_cron_parsing?
        @strict_cron_parsing
      end
    end
  end
end

Sidekiq::Cron.configure
