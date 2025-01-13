module Sidekiq
  module Cron
    class Namespace
      def self.all
        namespaces = Sidekiq::Cron.configuration.available_namespaces
        return namespaces if namespaces

        Sidekiq.redis do |conn|
          namespaces = conn.keys('cron_jobs:*').collect do |key|
            key.split(':').last
          end
        end

        # Adds the default namespace if not present
        has_default = namespaces.detect do |name|
          name == Sidekiq::Cron.configuration.default_namespace
        end

        unless has_default
          namespaces << Sidekiq::Cron.configuration.default_namespace
        end

        namespaces
      end

      def self.all_with_count
        all.map do |namespace_name|
          {
            count: count(namespace_name),
            name: namespace_name
          }
        end
      end

      def self.count(name = Sidekiq::Cron.configuration.default_namespace)
        out = 0
        Sidekiq.redis do |conn|
          out = conn.scard("cron_jobs:#{name}")
        end
        out
      end

      def self.available_namespaces_provided?
        !!Sidekiq::Cron.configuration.available_namespaces
      end
    end
  end
end
