require './test/test_helper'

describe 'Cron Poller' do
  before do
    REDIS.with { |c| c.respond_to?(:redis) ? c.redis.flushdb : c.flushdb }
    Sidekiq.redis = REDIS

    # Clear all previous saved data from Redis.
    Sidekiq.redis do |conn|
      conn.keys("cron_job*").each do |key|
        conn.del(key)
      end
    end


    @args = {
      name: "Test",
      cron: "*/2 * * * *",
      klass: "CronTestClass"
    }
    @args2 = @args.merge(name: 'with_queue', klass: 'CronTestClassWithQueue', cron: "*/10 * * * *")

    @poller = Sidekiq::Cron::Poller.new
  end

  it 'not enqueue any job - new jobs' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 5, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(@args)
    Sidekiq::Cron::Job.create(@args2)

    @poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    # 30 seconds after!
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 5, 30)
    Time.stubs(:now).returns(enqueued_time)

    @poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end
  end

  it 'should enqueue only job with cron */2' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 5, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(@args)
    Sidekiq::Cron::Job.create(@args2)

    @poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 6, 1)
    Time.stubs(:now).returns(enqueued_time)
    @poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end
  end

  it 'should enqueue both jobs' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 8, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(@args)
    Sidekiq::Cron::Job.create(@args2)

    @poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 10, 5)
    Time.stubs(:now).returns(enqueued_time)
    @poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end
  end

  it 'should enqueue both jobs but only one time each' do
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 8, 1)
    Time.stubs(:now).returns(enqueued_time)

    Sidekiq::Cron::Job.create(@args)
    Sidekiq::Cron::Job.create(@args2)

    @poller.enqueue

    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default")
      assert_equal 0, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 1)
    Time.stubs(:now).returns(enqueued_time)
    @poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 2)
    Time.stubs(:now).returns(enqueued_time)
    @poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 20)
    Time.stubs(:now).returns(enqueued_time)
    @poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end

    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 20, 50)
    Time.stubs(:now).returns(enqueued_time)
    @poller.enqueue
    Sidekiq.redis do |conn|
      assert_equal 1, conn.llen("queue:default")
      assert_equal 1, conn.llen("queue:super")
    end
  end
end
