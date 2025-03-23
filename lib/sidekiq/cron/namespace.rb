module Sidekiq
  module Cron
    class Namespace
      def self.all
        namespaces = Sidekiq::Cron.configuration.available_namespaces || begin
          Sidekiq.redis do |conn|
            conn.keys('cron_jobs:*').collect do |key|
              key.split(':').last
            end
          end
        end

        namespaces | [Sidekiq::Cron.configuration.default_namespace]
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
        Sidekiq.redis do |conn|
          conn.scard("cron_jobs:#{name}")
        end
      end

      def self.available_namespaces_provided?
        !!Sidekiq::Cron.configuration.available_namespaces
      end
    end
  end
end
