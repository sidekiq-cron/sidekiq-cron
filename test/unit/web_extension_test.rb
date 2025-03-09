require './test/test_helper'

describe 'Cron web' do
  include Rack::Test::Methods

  TOKEN = SecureRandom.base64(32).freeze

  def app
    Sidekiq::Web
  end

  before do
    env 'rack.session', { csrf: TOKEN }
    env 'HTTP_X_CSRF_TOKEN', TOKEN

    Sidekiq::Cron.reset!
    Sidekiq.redis(&:flushdb)

    if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("8.0.0")
      Sidekiq::Web.configure do |c|
        # Remove CSRF protection
        # See: https://github.com/sidekiq/sidekiq/blob/0a1bce30e562357e0bb60ce84d78fe5d8446bed9/test/webext_test.rb#L37
        c.middlewares.clear
      end
    end
  end

  let(:job_name) { "TestNameOfCronJob" }
  let(:cron_job_name) { "TesQueueNameOfCronJob" }

  let(:args) do
    {
      name: job_name,
      cron: "*/2 * * * *",
      klass: "CronTestClass"
    }
  end

  let(:cron_args) do
    {
      name: cron_job_name,
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
    Sidekiq::Cron::Job.create(args)

    get '/cron'
    assert_equal 200, last_response.status
    refute last_response.body.include?('No cron jobs were found')
    assert last_response.body.include?('table')
    assert last_response.body.include?("TestNameOfCronJob")
  end

  describe "work with cron job" do
    before do
      @job = Sidekiq::Cron::Job.new(args.merge(status: "enabled"))
      assert @job.save

      @cron_job = Sidekiq::Cron::Job.new(cron_args.merge(status: "enabled"))
      assert @cron_job.save
    end

    it 'shows namespaced jobs' do
      get '/cron/namespaces/default'

      assert last_response.body.include?(job_name)
    end

    it 'shows history of a cron job' do
      @job.enqueue!
      get "/cron/namespaces/default/jobs/#{job_name}"

      jid =
        Sidekiq.redis do |conn|
          history = conn.lrange Sidekiq::Cron::Job.jid_history_key(job_name), 0, -1
          Sidekiq.load_json(history.last)['jid']
        end

      assert jid
      assert last_response.body.include?(jid)
    end

    it 'redirects to cron path when name not found' do
      get '/cron/namespaces/default/jobs/some-fake-name'

      assert_match %r{\/cron\/namespaces\/default\z}, last_response['Location']
    end

    it "disable and enable all cron jobs" do
      post "/cron/namespaces/default/all/disable"
      assert_equal Sidekiq::Cron::Job.find(job_name).status, "disabled"

      post "/cron/namespaces/default/all/enable"
      assert_equal Sidekiq::Cron::Job.find(job_name).status, "enabled"
    end

    it "disable and enable cron job" do
      post "/cron/namespaces/default/jobs/#{job_name}/disable"
      assert_equal Sidekiq::Cron::Job.find(job_name).status, "disabled"

      post "/cron/namespaces/default/jobs/#{job_name}/enable"
      assert_equal Sidekiq::Cron::Job.find(job_name).status, "enabled"
    end

    it "enqueue all jobs" do
      Sidekiq.redis do |conn|
        assert_equal 0, conn.llen("queue:default"), "Queue should have no jobs"
      end

      post "/cron/namespaces/default/all/enqueue"

      Sidekiq.redis do |conn|
        assert_equal 1, conn.llen("queue:default"), "Queue should have 1 job in default"
        assert_equal 1, conn.llen("queue:cron"), "Queue should have 1 job in cron"
      end
    end

    it "enqueue job" do
      Sidekiq.redis do |conn|
        assert_equal 0, conn.llen("queue:default"), "Queue should have no jobs"
      end

      post "/cron/namespaces/default/jobs/#{job_name}/enqueue"

      Sidekiq.redis do |conn|
        assert_equal 1, conn.llen("queue:default"), "Queue should have 1 job"
      end

      # Should enqueue more times.
      post "/cron/namespaces/default/jobs/#{job_name}/enqueue"

      Sidekiq.redis do |conn|
        assert_equal 2, conn.llen("queue:default"), "Queue should have 2 job"
      end

      # Should enqueue to cron job queue.
      post "/cron/namespaces/default/jobs/#{cron_job_name}/enqueue"

      Sidekiq.redis do |conn|
        assert_equal 1, conn.llen("queue:cron"), "Queue should have 1 cron job"
      end
    end

    it "destroy job" do
      assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 job"
      post "/cron/namespaces/default/jobs/#{job_name}/delete"
      post "/cron/namespaces/default/jobs/#{cron_job_name}/delete"
      assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have zero jobs"
    end

    it "destroy all jobs" do
      assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs"
      post "/cron/namespaces/default/all/delete"
      assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have zero jobs"
    end
  end

  describe 'work with cron jobs from a custom namespace' do
    let(:namespace) { 'my-custom-namespace' }

    let(:namespaced_job_name) { 'NamespacedCronJobTestName' }

    let(:namespaced_args) do
      args.merge(queue: 'namespaced', name: namespaced_job_name,
                 namespace: namespace, status: 'enabled')
    end

    before do
      @job = Sidekiq::Cron::Job.new(namespaced_args)
      assert @job.save
    end

    it "doesn't show from the default namespace" do
      get '/cron/namespaces/default'

      assert last_response.body.include?('No cron jobs were found')
    end

    it 'shows namespaced jobs' do
      get "/cron/namespaces/#{namespace}"

      assert last_response.body.include?(namespaced_job_name)
    end

    describe 'with a cron job in the default namespace' do
      before do
        @job = Sidekiq::Cron::Job.new(args.merge(status: 'enabled'))
        assert @job.save
      end

      # Be sure the default job is present
      it 'shows namespaced jobs' do
        get '/cron/namespaces/default'

        assert last_response.body.include?(job_name)
      end

      it 'disable and enable all cron jobs from my custom namespace only' do
        assert_equal Sidekiq::Cron::Job.find(job_name).status, 'enabled'
        assert_equal Sidekiq::Cron::Job.find(namespaced_job_name, namespace).status, 'enabled'

        post "/cron/namespaces/#{namespace}/all/disable"
        assert_equal Sidekiq::Cron::Job.find(job_name).status, 'enabled'
        assert_equal Sidekiq::Cron::Job.find(namespaced_job_name, namespace).status, 'disabled'

        post "/cron/namespaces/#{namespace}/all/enable"
        assert_equal Sidekiq::Cron::Job.find(job_name).status, 'enabled'
        assert_equal Sidekiq::Cron::Job.find(namespaced_job_name, namespace).status, 'enabled'
      end

      it 'enqueue all jobs' do
        Sidekiq.redis do |conn|
          assert_equal 0, conn.llen('queue:default'), 'Queue should have no jobs'
        end

        post "/cron/namespaces/#{namespace}/all/enqueue"

        Sidekiq.redis do |conn|
          # The job from the 'default' namespace shouldn't be queued
          assert_equal 0, conn.llen('queue:default'), 'Queue should have 0 job in default'
          # But the namespaced job should be queued
          assert_equal 1, conn.llen('queue:namespaced'), 'Queue should have 1 job in default'
        end
      end

      it 'destroy all jobs' do
        assert_equal Sidekiq::Cron::Job.all.size, 1, 'Should have 1 job in the default namespace'
        assert_equal Sidekiq::Cron::Job.all(namespace).size, 1, "Should have 1 job in the #{namespace} namespace"

        post "/cron/namespaces/#{namespace}/all/delete"

        assert_equal Sidekiq::Cron::Job.all.size, 1, 'Should have 1 job in the default namespace'
        assert_equal Sidekiq::Cron::Job.all(namespace).size, 0, "Should have zero jobs in the #{namespace} namespace"
      end
    end
  end
end
