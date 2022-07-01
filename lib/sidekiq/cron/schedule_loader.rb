require "sidekiq"
require "sidekiq/cron/job"

if Sidekiq.server?
  Sidekiq.configure_server do |config|
    cron_schedule_file = Sidekiq.respond_to?(:[]) ? Sidekiq[:cron_schedule_file] : Sidekiq.options[:cron_schedule_file]
    schedule_file = cron_schedule_file || "config/schedule.yml"

    if File.exist?(schedule_file)
      config.on(:startup) do
        Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
      end
    end
  end
end
