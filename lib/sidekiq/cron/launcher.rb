# require cron poller
require 'sidekiq/cron/poller'

# For Cron we need to add some methods to Launcher
# so look at the code bellow.
#
# we are creating new cron poller instance and
# adding start and stop commands to launcher
module Sidekiq
  module Cron
    module Launcher
      # Add cron poller to launcher
      attr_reader :cron_poller

      # add cron poller and execute normal initialize of Sidekiq launcher
      def initialize(options)
        @cron_poller = Sidekiq::Cron::Poller.new
        super(options)
      end

      # execute normal run of launcher and run cron poller
      def run
        super
        cron_poller.start
      end

      # execute normal quiet of launcher and quiet cron poller
      def quiet
        cron_poller.terminate
        super
      end

      # execute normal stop of launcher and stop cron poller
      def stop
        cron_poller.terminate
        super
      end
    end
  end
end

Sidekiq.configure_server do
  # require  Sidekiq original launcher
  require 'sidekiq/launcher'

  ::Sidekiq::Launcher.prepend(Sidekiq::Cron::Launcher)
end
