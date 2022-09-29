require './test/test_helper'

describe 'Cron launcher' do
  describe 'initialization' do
    before do
      Sidekiq::Options[:cron_poll_interval] = nil
    end

    it 'initializes poller with default poll interval when not configured' do
      Sidekiq::Cron::Poller.expects(:new).with do |options|
        assert_equal Sidekiq::Cron::Launcher::DEFAULT_POLL_INTERVAL, options[:cron_poll_interval]
      end

      Sidekiq::Launcher.new(Sidekiq)
    end

    it 'initializes poller with the configured poll interval' do
      Sidekiq::Cron::Poller.expects(:new).with do |options|
        assert_equal 99, options[:cron_poll_interval]
      end

      Sidekiq::Options[:cron_poll_interval] = 99
      Sidekiq::Launcher.new(Sidekiq)
    end

    it 'does not initialize the poller when interval is 0' do
      Sidekiq::Cron::Poller.expects(:new).never

      Sidekiq::Options[:cron_poll_interval] = 0
      Sidekiq::Launcher.new(Sidekiq)
    end
  end
end
