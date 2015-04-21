begin
  require "sidekiq/web"
rescue LoadError
  # client-only usage
end

require "sidekiq/cron/job"
require "sidekiq/cron/web_extension"

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

if defined?(Sidekiq::Web)
  Sidekiq::Web.register Sidekiq::Cron::WebExtension

  if Sidekiq::Web.tabs.is_a?(Array)
    # For sidekiq < 2.5
    Sidekiq::Web.tabs << "cron"
  else
    Sidekiq::Web.tabs["Cron"] = "cron"
  end
end
