# frozen_string_literal: true

require './test/test_helper'

#
# Prevents Sidekiq::Scheduler to run the safe_thread helper method
module Sidekiq
  module Scheduled
    class Poller
      def start; end
    end
  end
end

describe 'Cron Poller' do
  # Clear all previous saved data from Redis.
  before { Sidekiq.redis(&:flushdb) }

  let(:args) do
    {
      name: "Test",
      cron: "*/2 * * * *",
      klass: "CronTestClass"
    }
  end

  let(:args2) do
    args.merge(name: 'with_queue', klass: 'CronTestClassWithQueue', cron: "*/10 * * * *")
  end

  let(:no_namespace_to_hash) do
    {
      name: 'no-namespace-test-job',
      klass: 'NoNamespaceCronTestClass',
      cron: '* * * * *',
      description: '',
      args: '[]',
      message: '{}',
      status: 'enabled',
      active_job: '1',
      queue_name_prefix: nil,
      queue_name_delimiter: nil,
      last_enqueue_time: nil,
      symbolize_args: '0'
    }
  end

  let(:poller) do
    Sidekiq::Cron::Poller.new(Sidekiq.const_defined?(:Config) ? Sidekiq::Config.new : {})
  end

  describe 'on startup' do
    before do
      time = Time.now.utc
      # A job created without a namespace, like it would have been prior to
      # namespaces implementation.
      Sidekiq.redis do |conn|
        conn.zadd 'cron_jobs', time.to_f.to_s, 'cron_job:no-namespace-job'
        conn.hset 'cron_job:no-namespace-job',
                  (no_namespace_to_hash.transform_values! { |v| v || '' })
      end
    end

    describe 'before the migration code runs' do
      it 'should have one job out of any namespaces' do
        assert_equal 1,
                     Sidekiq.redis { |conn| conn.zrange('cron_jobs', 0, -1) }.size,
                     'Should have 1 old job'
        assert_equal 0,
                     Sidekiq.redis { |conn| conn.zrange('cron_jobs:default', 0, -1) }.size,
                     'Should have 0 jobs in the default namespace'
      end
    end

    describe 'after the migration code has run' do
      before { poller.start }

      it 'should not have any job out of any namespaces' do
        assert_equal 0,
                     Sidekiq.redis { |conn| conn.zrange('cron_jobs', 0, -1) }.size,
                     'Should have 0 old jobs'
        assert_equal 1,
                     Sidekiq.redis { |conn| conn.zrange('cron_jobs:default', 0, -1) }.size,
                     'Should have 1 job in the default namespace'
      end
    end
  end

  it 'not enqueue any job - new jobs' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 5, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(args)
    Sidekiq::Cron::Job.create(args2)

    poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    # 30 seconds after!
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 5, 30)
    Time.stubs(:now).returns(enqueued_time)

    poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end
  end

  it 'should enqueue only job with cron */2' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 5, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(args)
    Sidekiq::Cron::Job.create(args2)

    poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 6, 1)
    Time.stubs(:now).returns(enqueued_time)
    poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end
  end

  it 'should enqueue both jobs' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 8, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(args)
    Sidekiq::Cron::Job.create(args2)

    poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 10, 5)
    Time.stubs(:now).returns(enqueued_time)
    poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end
  end

  it 'should enqueue both jobs but only one time each' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 8, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(args)
    Sidekiq::Cron::Job.create(args2)

    poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 1)
    Time.stubs(:now).returns(enqueued_time)
    poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 2)
    Time.stubs(:now).returns(enqueued_time)
    poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 20)
    Time.stubs(:now).returns(enqueued_time)
    poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 50)
    Time.stubs(:now).returns(enqueued_time)
    poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end
  end
end
