require './test/test_helper'

describe 'ScheduleLoader' do
  before do
    Sidekiq::Options[:lifecycle_events][:startup].clear
  end

  describe 'Schedule is defined in hash' do
    before do
      Sidekiq::Options[:cron_schedule_file] = 'test/unit/fixtures/schedule_hash.yml'
      load 'sidekiq/cron/schedule_loader.rb'
    end

    it 'calls Sidekiq::Cron::Job.load_from_hash' do
      Sidekiq::Cron::Job.expects(:load_from_hash!)
      Sidekiq::Options[:lifecycle_events][:startup].first.call
    end
  end

  describe 'Schedule is defined in array' do
    before do
      Sidekiq::Options[:cron_schedule_file] = 'test/unit/fixtures/schedule_array.yml'
      load 'sidekiq/cron/schedule_loader.rb'
    end

    it 'calls Sidekiq::Cron::Job.load_from_array' do
      Sidekiq::Cron::Job.expects(:load_from_array!)
      Sidekiq::Options[:lifecycle_events][:startup].first.call
    end
  end

  describe 'Schedule is not defined in hash nor array' do
    before do
      Sidekiq::Options[:cron_schedule_file] = 'test/unit/fixtures/schedule_string.yml'
      load 'sidekiq/cron/schedule_loader.rb'
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
      Sidekiq::Options[:cron_schedule_file] = 'test/unit/fixtures/schedule_erb.yml'
      load 'sidekiq/cron/schedule_loader.rb'

      Sidekiq::Options[:lifecycle_events][:startup].first.call

      job = Sidekiq::Cron::Job.find("daily_job")
      assert_equal job.klass, "DailyJob"
      assert_equal job.cron, "every day at 5 pm"
    end
  end
end
