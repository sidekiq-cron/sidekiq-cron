require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/actor'
require 'sidekiq/cron'

module Sidekiq
  module Cron

    POLL_INTERVAL = 10

    ##
    # The Poller checks Redis every N seconds for sheduled cron jobs
    class Poller
      include Util
      include Actor

      def poll(first_time=false)
        watchdog('scheduling cron poller thread died!') do
          add_jitter if first_time

          begin
            time_now = Time.now

            #go through all jobs
            Sidekiq::Cron::Job.all.each do |job|
              #test if job should be enequed
              # if yes add job to queue
              begin
                job.test_and_enque_for_time! time_now if job && job.valid?
              rescue => ex
                #problem somewhere in one job
                logger.error "CRON JOB: #{ex.message}"
                logger.error "CRON JOB: #{ex.backtrace.first}"
              end
            end

          rescue Exception => ex
            # Most likely a problem with redis networking.
            # Punt and try again at the next interval
            logger.error ex.message
            logger.error ex.backtrace.first
          end

          after(poll_interval) { poll }
        end
      end

      private

      def poll_interval
        Sidekiq.options[:poll_interval] || POLL_INTERVAL
      end

      def add_jitter
        begin
          sleep(poll_interval * rand)
        rescue Celluloid::Task::TerminatedError
          # Hit Ctrl-C when Sidekiq is finished booting and we have a chance
          # to get here.
        end
      end

    end
  end
end
