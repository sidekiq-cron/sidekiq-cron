module ScheduleLoader
  def self.load_schedules(schedule_file = Sidekiq::Cron.configuration.cron_schedule_file)
    return unless File.exist?(schedule_file)

    schedule = Sidekiq::Cron::Support.load_yaml(ERB.new(IO.read(schedule_file)).result)
    case schedule
    when Hash
      Sidekiq::Cron::Job.load_from_hash!(schedule, source: "schedule")
    when Array
      Sidekiq::Cron::Job.load_from_array!(schedule, source: "schedule")
    else
      raise "Not supported schedule format. Confirm your #{schedule_file}"
    end
  end
end

ScheduleLoader.load_schedules
