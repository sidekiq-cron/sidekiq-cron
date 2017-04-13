# -*- encoding : utf-8 -*-
require './test/test_helper'
require 'benchmark'

describe 'Perfromance Poller' do
  X = 10000
  before do
    Sidekiq.redis = REDIS
    Sidekiq.redis do |conn|
      conn.flushdb
    end

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
    now = Time.now.utc
    enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 10, 5)
    Time.stubs(:now).returns(enqueued_time)
  end

  it 'should enqueue 10000 jobs in less than 30s' do
    Sidekiq.redis do |conn|
      assert_equal 0, conn.llen("queue:default"), 'Queue should be empty'
    end

    bench = Benchmark.measure {
      @poller.enqueue
    }

    Sidekiq.redis do |conn|
      assert_equal X, conn.llen("queue:default"), 'Queue should be full'
    end

    puts "Perfomance test finished in #{bench.real}"
    assert_operator 30, :>, bench.real
  end
end
