# frozen_string_literal: true

require './test/test_helper'

describe 'Namespace-aware polling configuration' do
  before do
    Sidekiq::Cron.reset!
    Sidekiq.redis(&:flushdb)
  end

  after do
    Sidekiq::Cron.configure do |config|
      config.cron_poll_namespace = nil
    end
  end

  describe 'cron_poll_namespace configuration' do
    it 'defaults to nil' do
      assert_nil Sidekiq::Cron.configuration.cron_poll_namespace
    end

    it 'can be set to a specific namespace' do
      Sidekiq::Cron.configure do |config|
        config.cron_poll_namespace = 'domain_a'
      end

      assert_equal 'domain_a', Sidekiq::Cron.configuration.cron_poll_namespace
    end

    it 'can be changed during runtime' do
      Sidekiq::Cron.configure do |config|
        config.cron_poll_namespace = 'domain_b'
      end

      assert_equal 'domain_b', Sidekiq::Cron.configuration.cron_poll_namespace

      Sidekiq::Cron.configure do |config|
        config.cron_poll_namespace = 'domain_a'
      end

      assert_equal 'domain_a', Sidekiq::Cron.configuration.cron_poll_namespace
    end
  end

  describe 'load_from_array! namespace isolation' do
    let(:domain_a_jobs) do
      [
        { name: 'job1', cron: '*/5 * * * *', class: 'Worker1' },
        { name: 'job2', cron: '*/5 * * * *', class: 'Worker2' }
      ]
    end

    let(:domain_b_jobs) do
      [
        { name: 'job3', cron: '*/5 * * * *', class: 'Worker3' },
        { name: 'job4', cron: '*/5 * * * *', class: 'Worker4' }
      ]
    end

    before do
      Sidekiq::Cron.configure do |config|
        config.available_namespaces = %w[domain_a domain_b]
      end
    end

    describe 'loading jobs to specific namespace' do
      it 'loads jobs only to the specified namespace' do
        Sidekiq::Cron::Job.load_from_array!(domain_a_jobs, { namespace: 'domain_a' })

        domain_a_ns_jobs = Sidekiq::Cron::Job.all('domain_a')
        domain_b_ns_jobs = Sidekiq::Cron::Job.all('domain_b')

        assert_equal 2, domain_a_ns_jobs.size
        assert_includes domain_a_ns_jobs.map(&:name), 'job1'
        assert_includes domain_a_ns_jobs.map(&:name), 'job2'
        assert_equal 0, domain_b_ns_jobs.size
      end
    end

    describe 'preventing cross-namespace job deletion' do
      it 'does not delete jobs from other namespaces when loading new jobs' do
        # Worker A boots first and loads its jobs
        Sidekiq::Cron::Job.load_from_array!(domain_a_jobs, { namespace: 'domain_a' })

        # Worker B boots second and loads its jobs
        Sidekiq::Cron::Job.load_from_array!(domain_b_jobs, { namespace: 'domain_b' })

        # Both namespaces should have their jobs intact
        domain_a_ns_jobs = Sidekiq::Cron::Job.all('domain_a')
        domain_b_ns_jobs = Sidekiq::Cron::Job.all('domain_b')

        assert_equal 2, domain_a_ns_jobs.size
        assert_includes domain_a_ns_jobs.map(&:name), 'job1'
        assert_includes domain_a_ns_jobs.map(&:name), 'job2'

        assert_equal 2, domain_b_ns_jobs.size
        assert_includes domain_b_ns_jobs.map(&:name), 'job3'
        assert_includes domain_b_ns_jobs.map(&:name), 'job4'
      end
    end
  end
end
