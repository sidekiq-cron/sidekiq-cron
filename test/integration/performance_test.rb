# -*- encoding : utf-8 -*-
require './test/test_helper'
require 'benchmark'

describe 'Performance Poller' do
  X = 10000
  before do
    Sidekiq.redis = REDIS
    Redis.current.flushdb

    #clear all previous saved data from redis
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

    X.times do |i|
      Sidekiq::Cron::Job.create(args.merge(name: "Test#{i}"))
    end

    @poller = Sidekiq::Cron::Poller.new
    now = Time.now.utc + 3600
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour, 10, 5)
    Time.stubs(:now).returns(enqueued_time)
  end

  it 'should enqueue 10000 jobs in less than 40s' do
    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default"), 'Queue should be empty'
    end

    bench = Benchmark.measure {
      @poller.enqueue
    }

    Sidekiq.redis do |conn|
      assert_equal X, conn.llen("queue:default"), 'Queue should be full'
    end

    puts "Performance test finished in #{bench.real}"
    assert_operator bench.real, :<, 40
  end
end
