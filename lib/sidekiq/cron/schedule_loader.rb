require 'sidekiq'
require 'sidekiq/cron/job'
require 'sidekiq/options'

if Sidekiq.server?
  Sidekiq.configure_server do |config|
    schedule_file = Sidekiq::Options[:cron_schedule_file] || 'config/schedule.yml'

    if File.exist?(schedule_file)
      config.on(:startup) do
        schedule = Sidekiq::Cron::Support.load_yaml(ERB.new(IO.read(schedule_file)).result)
        if schedule.kind_of?(Hash)
          Sidekiq::Cron::Job.load_from_hash schedule
        elsif schedule.kind_of?(Array)
          Sidekiq::Cron::Job.load_from_array schedule
        else
          raise "Not supported schedule format. Confirm your #{schedule_file}"
        end
      end
    end
  end
end
