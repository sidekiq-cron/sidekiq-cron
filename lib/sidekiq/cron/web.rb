require "sidekiq/cron/web_extension"
require "sidekiq/cron/job"
require "sidekiq/cron/namespace"

if defined?(Sidekiq::Web)
  if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('8.0.0')
    Sidekiq::Web.configure do |config|
      config.register(
        Sidekiq::Cron::WebExtension, # Class which contains the HTTP actions, required
        name: "cron", # the name of the extension, used to namespace assets
        tab: "Cron", # labels(s) of the UI tabs
        index: "cron", # index route(s) for each tab
      )
    end
  elsif Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.3.0')
    Sidekiq::Web.register(
      Sidekiq::Cron::WebExtension, # Class which contains the HTTP actions, required
      name: "cron", # the name of the extension, used to namespace assets
      tab: "Cron", # labels(s) of the UI tabs
      index: "cron", # index route(s) for each tab
    )
  else
    Sidekiq::Web.register Sidekiq::Cron::WebExtension
    Sidekiq::Web.tabs["Cron"] = "cron"
  end
end
