# frozen_string_literal: true

require './test/test_helper'

describe 'Namespaces' do
  before do
    # Clear all previous saved data from Redis.
    Sidekiq.redis do |conn|
      conn.keys("cron_job*").each do |key|
        conn.del(key)
      end
    end

    # Clear all queues.
    Sidekiq::Queue.all.each do |queue|
      queue.clear
    end
  end

  let(:args) do
    {
      name: 'Test',
      cron: '* * * * *',
      klass: 'CronTestClass'
    }
  end

  describe 'all' do
    it 'returns all the existing namespaces' do
      # new jobs!
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace1'))
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace2'))

      expected = %w[default namespace1 namespace2]

      assert_equal Sidekiq::Cron::Namespace.all.sort, expected
    end
  end

  describe 'count' do
    it 'returns the jobs count per namespaces' do
      # new jobs!
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace1'))
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace2'))

      assert_equal Sidekiq::Cron::Namespace.count,
                   0,
                   'Count should be zero from the "default" namespace'
      assert_equal Sidekiq::Cron::Namespace.count('namespace1'),
                   1,
                   'Count should be one from the "namespace1" namespace'
      assert_equal Sidekiq::Cron::Namespace.count('namespace2'),
                   1,
                   'Count should be one from the "namespace2" namespace'
    end
  end

  describe 'all_with_count' do
    it 'returns an Array of Hashes with the jobs count per namespaces' do
      # new jobs!
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace1'))
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace2'))
      Sidekiq::Cron::Job.create(args.merge(name: 'Test2',
                                           namespace: 'namespace2'))

      counts = Sidekiq::Cron::Namespace.all_with_count.sort_by do |hash|
        hash[:name]
      end

      expected = [{ name: 'default', count: 0 },
                  { name: 'namespace1', count: 1 },
                  { name: 'namespace2', count: 2 }]

      assert_equal counts, expected
    end
  end
end
