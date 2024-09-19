require 'sidekiq/cron/config'

module Sidekiq
  module Cron
    class Namespace
      def self.all
        namespaces = nil

        Sidekiq.redis do |conn|
          namespaces = conn.keys('cron_jobs:*').collect do |key|
            key.split(':').last
          end
        end

        # Adds the default namespace if not present
        has_default = namespaces.detect do |name|
          name == Sidekiq::Cron::Config.default_namespace
        end

        unless has_default
          namespaces << Sidekiq::Cron::Config.default_namespace
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

      def self.count(name = Sidekiq::Cron::Config.default_namespace)
        out = 0
        Sidekiq.redis do |conn|
          out = conn.scard("cron_jobs:#{name}")
        end
        out
      end
    end
  end
end
