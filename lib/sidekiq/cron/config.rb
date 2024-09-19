require "singleton"

module Sidekiq
  module Cron
    class Config
      include Singleton
      extend SingleForwardable

      # The default namespace is used when no namespace is specified.
      attr_accessor :default_namespace

      # The parsing mode when using the natural language cron syntax from the `fugit` gem.
      #
      # :single -- use the first parsed cron line and ignore the rest (default)
      # :strict -- raise an error if multiple cron lines are parsed from one string
      attr_reader :natural_cron_parsing_mode

      # The poller will not enqueue jobs that are late by more than this amount of seconds.
      # Defaults to 60 seconds.
      #
      # This is useful when sidekiq (and sidekiq-cron) is not used in zero downtime deployments and
      # when the deployment is done and sidekiq-cron starts to catch up, it will consider older
      # jobs that missed their schedules during the deployment. E.g., jobs that run once a day.
      attr_accessor :reschedule_grace_period

      ALL_OPTIONS = %i[default_namespace natural_cron_parsing_mode reschedule_grace_period].freeze

      def self.configure
        yield(instance) if block_given?
      end

      def initialize
        @default_namespace = 'default'
        @natural_cron_parsing_mode = :single
        @reschedule_grace_period = 60
      end

      def natural_cron_parsing_mode=(mode)
        unless %i[single strict].include?(mode)
          raise ArgumentError, "Unknown natural cron parsing mode: #{mode.inspect}"
        end

        @natural_cron_parsing_mode = mode
      end

      delegate ALL_OPTIONS => :instance
    end
  end
end
