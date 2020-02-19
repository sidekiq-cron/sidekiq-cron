require './test/test_helper'

def app
  Sidekiq::Web
end

describe 'Cron web' do
  include Rack::Test::Methods

  before do
    Sidekiq.redis = REDIS
    Redis.current.flushdb

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


    @cron_args = {
      name: "TesQueueNameOfCronJob",
      cron: "*/2 * * * *",
      klass: "CronQueueTestClass",
      queue: "cron"
    }

  end

  it 'display cron web' do
    get '/cron'
    assert_equal 200, last_response.status
  end

  it 'display cron web with message - no cron jobs' do
    get '/cron'
    assert last_response.body.include?('No cron jobs were found')
  end

  it 'display cron web with cron jobs table' do
    Sidekiq::Cron::Job.create(@args)

    get '/cron'
    assert_equal 200, last_response.status
    refute last_response.body.include?('No cron jobs were found')
    assert last_response.body.include?('table')
    assert last_response.body.include?("TestNameOfCronJob")
  end

  describe "work with cron job" do

    before do
      @job = Sidekiq::Cron::Job.new(@args.merge(status: "enabled"))
      @job.save
      @name = "TestNameOfCronJob"

      @cron_job = Sidekiq::Cron::Job.new(@cron_args.merge(status: "enabled"))
      @cron_job.save
      @cron_job_name = "TesQueueNameOfCronJob"
    end

    it 'shows history of a cron job' do
      @job.enque!
      get "/cron/#{@name}"

      jid =
        Sidekiq.redis do |conn|
          history = conn.lrange Sidekiq::Cron::Job.jid_history_key(@name), 0, -1
          Sidekiq.load_json(history.last)['jid']
        end

      assert last_response.body.include?(jid)
    end

    it 'redirects to cron path when name not found' do
      get '/cron/some-fake-name'

      assert_match %r{\/cron\z}, last_response['Location']
    end

    it "disable and enable all cron jobs" do
      post "/cron/__all__/disable"
      assert_equal Sidekiq::Cron::Job.find(@name).status, "disabled"

      post "/cron/__all__/enable"
      assert_equal Sidekiq::Cron::Job.find(@name).status, "enabled"
    end

    it "disable and enable cron job" do
      post "/cron/#{@name}/disable"
      assert_equal Sidekiq::Cron::Job.find(@name).status, "disabled"

      post "/cron/#{@name}/enable"
      assert_equal Sidekiq::Cron::Job.find(@name).status, "enabled"
    end

    it "enqueue all jobs" do
      Sidekiq.redis do |conn|
        assert_equal 0, conn.llen("queue:default"), "Queue should have no jobs"
      end

      post "/cron/__all__/enque"

      Sidekiq.redis do |conn|
        assert_equal 1, conn.llen("queue:default"), "Queue should have 1 job in default"
        assert_equal 1, conn.llen("queue:cron"), "Queue should have 1 job in cron"
      end
    end

    it "enqueue job" do
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

      #should enqueue to cron job queue
      post "/cron/#{@cron_job_name}/enque"

      Sidekiq.redis do |conn|
        assert_equal 1, conn.llen("queue:cron"), "Queue should have 1 cron job"
      end
    end

    it "destroy job" do
      assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 job"
      post "/cron/#{@name}/delete"
      post "/cron/#{@cron_job_name}/delete"
      assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have zero jobs"
    end

    it "destroy all jobs" do
      assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 job"
      post "/cron/__all__/delete"
      assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have zero jobs"
    end
  end
end
