# -*- encoding : utf-8 -*-
require './test/test_helper'

class CronPollerTest < Test::Unit::TestCase

  context 'Cron Poller' do
    setup do
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


      @args = {
        name: "Test",
        cron: "*/2 * * * *",
        klass: "CronTestClass"
      }
      @args2 = @args.merge(name: 'with_queue', klass: 'CronTestClassWithQueue', cron: "*/10 * * * *")

      @poller = Sidekiq::Cron::Poller.new
    end


    should 'not enqueue any job - new jobs' do
      now = Time.now
      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 5, 1)
      Time.stub(:now, enqueued_time) do
        #new jobs!
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args2)

        @poller.poll 

        Sidekiq.redis do |conn|
          assert_equal 0, conn.llen("queue:default")
          assert_equal 0, conn.llen("queue:super")
        end
      end

      #30 seconds after!
      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 5, 30)
      Time.stub(:now, enqueued_time) do
        @poller.poll 

        Sidekiq.redis do |conn|
          assert_equal 0, conn.llen("queue:default")
          assert_equal 0, conn.llen("queue:super")
        end
      end
    end

    should 'should enqueue only job with cron */2' do
      now = Time.now
      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 5, 1)
      Time.stub(:now, enqueued_time) do
        #new jobs!
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args2)
        
        @poller.poll 
        
        Sidekiq.redis do |conn|
          assert_equal 0, conn.llen("queue:default")
          assert_equal 0, conn.llen("queue:super")
        end
      end

      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 6, 1)
      Time.stub(:now, enqueued_time) do        
        @poller.poll 
        
        Sidekiq.redis do |conn|
          assert_equal 1, conn.llen("queue:default")
          assert_equal 0, conn.llen("queue:super")
        end
      end
    end

    should 'should enqueue both jobs' do
      now = Time.now
      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 8, 1)
      Time.stub(:now, enqueued_time) do
        #new jobs!
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args2)
        
        @poller.poll 
        
        Sidekiq.redis do |conn|
          assert_equal 0, conn.llen("queue:default")
          assert_equal 0, conn.llen("queue:super")
        end
      end

      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 10, 5)
      Time.stub(:now, enqueued_time) do        
        @poller.poll 
        
        Sidekiq.redis do |conn|
          assert_equal 1, conn.llen("queue:default")
          assert_equal 1, conn.llen("queue:super")
        end
      end
    end

    should 'should enqueue both jobs but only one time each' do      
      now = Time.now
      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 8, 1)
      Time.stub(:now, enqueued_time) do
        #new jobs!
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args2)
        
        @poller.poll 
        
        Sidekiq.redis do |conn|
          assert_equal 0, conn.llen("queue:default")
          assert_equal 0, conn.llen("queue:super")
        end
      end

      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 20, 1)
      Time.stub(:now, enqueued_time) do
        @poller.poll false
        Sidekiq.redis do |conn|
          assert_equal 1, conn.llen("queue:default")
          assert_equal 1, conn.llen("queue:super")
        end
      end

      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 20, 2)
      Time.stub(:now, enqueued_time) do
        @poller.poll false
        Sidekiq.redis do |conn|
          assert_equal 1, conn.llen("queue:default")
          assert_equal 1, conn.llen("queue:super")
        end
      end

      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 20, 20)
      Time.stub(:now, enqueued_time) do
        @poller.poll false
        Sidekiq.redis do |conn|
          assert_equal 1, conn.llen("queue:default")
          assert_equal 1, conn.llen("queue:super")
        end
      end

      enqueued_time = Time.new(now.year, now.month, now.day, now.hour + 1, 20, 50)
      Time.stub(:now, enqueued_time) do
        @poller.poll false 
        Sidekiq.redis do |conn|
          assert_equal 1, conn.llen("queue:default")
          assert_equal 1, conn.llen("queue:super")
        end
      end
    end

  end
end
