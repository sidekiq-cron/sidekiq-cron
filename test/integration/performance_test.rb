require './test/test_helper'
require 'benchmark'

describe 'Performance Poller' do
  JOBS_NUMBER = 10_000
  MAX_SECONDS = 60

  before do
    REDIS.with { |c| c.respond_to?(:redis) ? c.redis.flushdb : c.flushdb }
    Sidekiq.redis = REDIS

    # Clear all previous saved data from Redis.
    Sidekiq.redis do |conn|
      conn.keys("cron_job*").each do |key|
        conn.del(key)
      end
    end

    args = {
      queue: "default",
      cron: "*/2 * * * *",
      klass: "CronTestClass"
    }

    JOBS_NUMBER.times do |i|
      Sidekiq::Cron::Job.create(args.merge(name: "Test#{i}"))
    end

    @poller = Sidekiq::Cron::Poller.new
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 10, 5)
    Time.stubs(:now).returns(enqueued_time)
  end

  it "should enqueue #{JOBS_NUMBER} jobs in less than #{MAX_SECONDS}s" do
    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default"), 'Queue should be empty'
    end

    bench = Benchmark.measure {
      @poller.enqueue
    }

    Sidekiq.redis do |conn|
      assert_equal JOBS_NUMBER, conn.llen("queue:default"), 'Queue should be full'
    end

    puts "Performance test finished in #{bench.real}"
    assert_operator bench.real, :<, MAX_SECONDS
  end
end
