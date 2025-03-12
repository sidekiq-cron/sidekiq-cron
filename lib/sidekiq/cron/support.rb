module Sidekiq
  module Cron
    module Support
      def self.safe_constantize(klass_name)
        Object.const_get(klass_name)
      rescue NameError
        nil
      end

      def self.load_yaml(src)
        if Psych::VERSION > "4.0"
          YAML.safe_load(src, permitted_classes: [Symbol], aliases: true)
        else
          YAML.load(src)
        end
      end
    end
  end
end
