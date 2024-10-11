require './test/test_helper'

describe 'Cron launcher' do
  describe 'initialization' do
    before do
      Sidekiq::Cron.reset!
    end

    it 'initializes poller with default poll interval when not configured' do
      Sidekiq::Cron::Poller.expects(:new).with do |options|
        assert_equal Sidekiq::Cron.configuration.cron_poll_interval, options[:cron_poll_interval]
      end

      Sidekiq::Launcher.new(Sidekiq::Options.config)
    end

    it 'initializes poller with the configured poll interval' do
      Sidekiq::Cron::Poller.expects(:new).with do |options|
        assert_equal Sidekiq::Cron.configuration.cron_poll_interval, options[:cron_poll_interval]
      end

      Sidekiq::Cron.configuration.cron_poll_interval = 99
      Sidekiq::Launcher.new(Sidekiq::Options.config)
    end

    it 'does not initialize the poller when interval is 0' do
      Sidekiq::Cron::Poller.expects(:new).never

      Sidekiq::Cron.configuration.cron_poll_interval = 0
      Sidekiq::Launcher.new(Sidekiq::Options.config)
    end
  end
end
