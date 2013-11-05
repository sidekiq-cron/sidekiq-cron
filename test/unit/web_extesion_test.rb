require './test/test_helper'

class CronWebExtensionTest < Test::Unit::TestCase
  context 'Cron web' do
    include Rack::Test::Methods

    def app
      Sidekiq::Web
    end

    setup do
      Sidekiq.redis = REDIS
      Sidekiq.redis {|c| c.flushdb }

      #clear all previous saved data from redis
      Sidekiq.redis do |conn|
        conn.keys("cron_job*").each do |key|
          conn.del(key)
        end
      end

      @args = {
        name: "TestNameOfCronJob",
        cron: "*/2 * * * *",
        klass: "CronTestClass"
      }

    end

    should 'display cron web' do
      get '/cron'
      assert_equal 200, last_response.status
    end

    should 'display cron web with message - no cron jobs' do
      get '/cron'
      assert last_response.body.include?('No cron jobs found')
    end

    should 'display cron web with cron jobs table' do
      Sidekiq::Cron::Job.create(@args)
      get '/cron'
      refute last_response.body.include?('No cron jobs found')
      assert last_response.body.include?('table')
      assert last_response.body.include?("TestNameOfCronJob")
    end

    context "work with cron job" do

      setup do
        @job = Sidekiq::Cron::Job.new(@args.merge(status: "enabled"))
        @job.save
        @name = "TestNameOfCronJob"
      end

      should "disable and enable cron job" do
        post "/cron/#{@name}/disable"
        assert_equal Sidekiq::Cron::Job.find(@name).status, "disabled"

        post "/cron/#{@name}/enable"
        assert_equal Sidekiq::Cron::Job.find(@name).status, "enabled"
      end

      should "enqueue job" do
        Sidekiq.redis do |conn|
          assert_equal 0, conn.llen("queue:default"), "Queue should have no jobs"
        end

        post "/cron/#{@name}/enque"

        Sidekiq.redis do |conn|
          assert_equal 1, conn.llen("queue:default"), "Queue should have 1 job"
        end

        #should enqueue more times
        post "/cron/#{@name}/enque"

        Sidekiq.redis do |conn|
          assert_equal 2, conn.llen("queue:default"), "Queue should have 2 job"
        end
      end

      should "destroy job" do
        assert_equal Sidekiq::Cron::Job.all.size, 1, "Should have 1 job"
        post "/cron/#{@name}/delete"
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have zero jobs"
      end


    end
  end
end
