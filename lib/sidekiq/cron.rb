require "sidekiq/cron/job"

#require poller only if celluloid is defined
if defined?(Celluloid)
  require 'celluloid/autostart'
  require "sidekiq/cron/poller"
  require "sidekiq/cron/launcher"
end

module Sidekiq
  module Cron
  end
end
