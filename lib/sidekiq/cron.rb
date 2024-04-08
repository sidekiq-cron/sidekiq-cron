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

      # The parsing mode when using the natural language cron syntax from the `fugit` gem.
      #
      # :single -- use the first parsed cron line and ignore the rest (default)
      # :strict -- raise an error if multiple cron lines are parsed from one string
      attr_reader :natural_cron_parsing_mode

      def initialize
        @default_namespace = 'default'
        @natural_cron_parsing_mode = :single
      end

      def natural_cron_parsing_mode=(mode)
        unless %i[single strict].include?(mode)
          raise ArgumentError, "Unknown natural cron parsing mode: #{mode.inspect}"
        end

        @natural_cron_parsing_mode = mode
      end
    end
  end
end

Sidekiq::Cron.configure
