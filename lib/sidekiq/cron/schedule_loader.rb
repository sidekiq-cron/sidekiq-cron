require 'sidekiq'
require 'sidekiq/cron/job'
require 'sidekiq/options'

if Sidekiq.server?
  Sidekiq.configure_server do |config|
    schedule_file = Sidekiq::Options[:cron_schedule_file] || 'config/schedule.yml'

    if File.exist?(schedule_file)
      config.on(:startup) do
        Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
      end
    end
  end
end
