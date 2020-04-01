require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/cron'
require 'sidekiq/scheduled'

module Sidekiq
  module Cron
    POLL_INTERVAL = 30

    # The Poller checks Redis every N seconds for sheduled cron jobs
    class Poller < Sidekiq::Scheduled::Poller
      def enqueue
        time = Time.now.utc
        Sidekiq::Cron::Job.all.each do |job|
          enqueue_job(job, time)
        end
      rescue => ex
        # Most likely a problem with redis networking.
        # Punt and try again at the next interval
        Sidekiq.logger.error ex.message
        Sidekiq.logger.error ex.backtrace.first
        handle_exception(ex) if respond_to?(:handle_exception)
      end

      private

      def enqueue_job(job, time = Time.now.utc)
        job.test_and_enque_for_time! time if job && job.valid?
      rescue => ex
        # problem somewhere in one job
        Sidekiq.logger.error "CRON JOB: #{ex.message}"
        Sidekiq.logger.error "CRON JOB: #{ex.backtrace.first}"
        handle_exception(ex) if respond_to?(:handle_exception)
      end

      def poll_interval_average
         Sidekiq.options[:poll_interval] || POLL_INTERVAL
      end
    end
  end
end
