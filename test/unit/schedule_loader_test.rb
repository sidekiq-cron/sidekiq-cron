require './test/test_helper'

describe 'ScheduleLoader' do
  before do
    Sidekiq::Cron.reset!
    Sidekiq::Options[:lifecycle_events][:startup].clear
    # Loaded before cron_schedule_file is set as this is the case for users of the gem
    load 'sidekiq/cron/schedule_loader.rb'
  end

  describe 'Schedule file does not exist' do
    before do
      Sidekiq::Cron.configuration.cron_schedule_file = 'test/unit/fixtures/schedule_does_not_exist.yml'
    end

    it 'does not call any sidekiq cron load methods' do
      Sidekiq::Cron::Job.expects(:load_from_hash!).never
      Sidekiq::Cron::Job.expects(:load_from_array!).never
      Sidekiq::Options[:lifecycle_events][:startup].first.call
    end

    sidekiq_version_has_embedded = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.0.0')
    if sidekiq_version_has_embedded
      it 'allows for sidekiq embedded configuration to be called without raising' do
        Sidekiq.configure_embed {}
      end
    end
  end

  describe 'Schedule is defined in hash' do
    before do
      Sidekiq::Cron.configuration.cron_schedule_file = 'test/unit/fixtures/schedule_hash.yml'
    end

    it 'calls Sidekiq::Cron::Job.load_from_hash!' do
      Sidekiq::Cron::Job.expects(:load_from_hash!)
      Sidekiq::Options[:lifecycle_events][:startup].first.call
    end
  end

  describe 'Schedule is defined in array' do
    before do
      Sidekiq::Cron.configuration.cron_schedule_file = 'test/unit/fixtures/schedule_array.yml'
    end

    it 'calls Sidekiq::Cron::Job.load_from_array!' do
      Sidekiq::Cron::Job.expects(:load_from_array!)
      Sidekiq::Options[:lifecycle_events][:startup].first.call
    end
  end

  describe 'Schedule is not defined in hash nor array' do
    before do
      Sidekiq::Cron.configuration.cron_schedule_file = 'test/unit/fixtures/schedule_string.yml'
    end

    it 'raises an error' do
      e = assert_raises StandardError do
        Sidekiq::Options[:lifecycle_events][:startup].first.call
      end
      assert_equal 'Not supported schedule format. Confirm your test/unit/fixtures/schedule_string.yml', e.message
    end
  end

  describe 'Schedule is defined using ERB' do
    it 'properly parses the schedule file' do
      Sidekiq::Cron.configuration.cron_schedule_file = 'test/unit/fixtures/schedule_erb.yml'

      Sidekiq::Options[:lifecycle_events][:startup].first.call

      job = Sidekiq::Cron::Job.find("daily_job")
      assert_equal job.klass, "DailyJob"
      assert_equal job.cron, "every day at 5 pm"
      assert_equal job.source, "schedule"
    end
  end

  describe 'Schedule file has .yaml extension' do
    before do
      Sidekiq::Cron.configuration.cron_schedule_file = 'test/unit/fixtures/schedule_yaml_extension.yml'
    end

    it 'loads the schedule file' do
      Sidekiq::Cron::Job.expects(:load_from_hash!)
      Sidekiq::Options[:lifecycle_events][:startup].first.call
    end
  end
end
