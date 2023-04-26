require "sidekiq/cron/job"
require "sidekiq/cron/poller"
require "sidekiq/cron/launcher"
require "sidekiq/cron/schedule_loader"

module Sidekiq
  module Cron
    def self.enabled_schedule_loader?
      Sidekiq::Options.fetch(:enable_default_cron_schedule, true) == true
    end
  end
end
