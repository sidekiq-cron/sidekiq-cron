require "sidekiq/cron/job"
require "sidekiq/cron/namespace"
require "sidekiq/cron/poller"
require "sidekiq/cron/launcher"
require "sidekiq/cron/schedule_loader"
require "sidekiq/cron/config"

module Sidekiq
  module Cron
    # @deprecated Use Sidekiq::Cron::Config.configure
    def self.configure
      Sidekiq::Cron::Config.configure(&block) if block_given?
    end
  end
end
