require "sidekiq/cron/web_extension"
require "sidekiq/cron/job"

if defined?(Sidekiq::Web)
  Sidekiq::Web.register Sidekiq::Cron::WebExtension

  if Sidekiq::Web.tabs.is_a?(Array)
    # For sidekiq < 2.5
    Sidekiq::Web.tabs << "cron"
  else
    Sidekiq::Web.tabs["Cron"] = "cron"
  end
end
