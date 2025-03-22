module Sidekiq
  module Cron
    class ScheduleLoader
      def load_schedule
        if schedule.is_a?(Hash)
          Sidekiq::Cron::Job.load_from_hash!(schedule, source: "schedule")
        elsif schedule.is_a?(Array)
          Sidekiq::Cron::Job.load_from_array!(schedule, source: "schedule")
        else
          raise "Not supported schedule format. Confirm your #{schedule_file_name}"
        end
      end

      def has_schedule_file?
        File.exist?(schedule_file_name)
      end

      private

      def schedule
        @schedule ||= Sidekiq::Cron::Support.load_yaml(rendered_schedule_template)
      end

      def rendered_schedule_template
        ERB.new(schedule_file_content).result
      end

      def schedule_file_content
        IO.read(schedule_file_name)
      end

      def schedule_file_name
        @schedule_file_name ||= yml_to_yaml_unless_file_exists(schedule_file_name_from_config)
      end

      def schedule_file_name_from_config
        Sidekiq::Cron.configuration.cron_schedule_file
      end

      def yml_to_yaml_unless_file_exists(file_name)
        if File.exist?(file_name)
          file_name
        else
          file_name.sub(/\.yml$/, ".yaml")
        end
      end
    end
  end
end

Sidekiq.configure_server do |config|
  config.on(:startup) do
    schedule_loader = Sidekiq::Cron::ScheduleLoader.new
    next unless schedule_loader.has_schedule_file?
    schedule_loader.load_schedule
  end
end
