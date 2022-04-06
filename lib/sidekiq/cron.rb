require "sidekiq/cron/job"
require "sidekiq/cron/poller"
require "sidekiq/cron/launcher"

module Sidekiq
  module Cron
    Redis.respond_to?(:exists_returns_integer) && Redis.exists_returns_integer =  false
  end
end
