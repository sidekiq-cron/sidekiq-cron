require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/cron'
require 'sidekiq/scheduled'

module Sidekiq
  module Cron
    # The Poller checks Redis every N seconds for sheduled cron jobs
    class Poller < Sidekiq::Scheduled::Poller
      def enqueue
        Sidekiq::Cron::Job.all.each do |job|
          enqueue_job(job)
        end
      rescue => ex
        # Most likely a problem with redis networking.
        # Punt and try again at the next interval
        logger.error ex.message
        logger.error ex.backtrace.first
      end

      private

      def enqueue_job(job)
        job.test_and_enque_for_time! Time.now if job && job.valid?
      rescue => ex
        # problem somewhere in one job
        logger.error "CRON JOB: #{ex.message}"
        logger.error "CRON JOB: #{ex.backtrace.first}"
      end
    end
  end
end
