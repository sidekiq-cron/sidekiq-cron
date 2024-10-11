module Sidekiq
  module Cron
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def self.reset!
      self.configuration = Configuration.new
    end

    class Configuration
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

      # The maximum number of recent cron job execution histories to retain.
      # This value controls how many past job executions are stored.
      attr_accessor :cron_history_size

      # The interval, in seconds, at which to poll for scheduled cron jobs.
      # This determines how frequently the scheduler checks for jobs to enqueue.
      attr_accessor :cron_poll_interval

      # The path to a YAML file containing multiple cron job schedules.
      # This file should use the same format as Resque-scheduler for job definitions.
      attr_accessor :cron_schedule_file

      def initialize
        @default_namespace = 'default'
        @natural_cron_parsing_mode = :single
        @reschedule_grace_period = 60
        @cron_history_size = 10
        @cron_poll_interval = 30
        @cron_schedule_file = 'config/schedule.yml'
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
