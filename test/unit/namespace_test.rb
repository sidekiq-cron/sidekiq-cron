# frozen_string_literal: true

require './test/test_helper'

describe 'Namespaces' do
  before do
    Sidekiq::Cron.reset!

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
    it 'returns all the existing namespaces if `available_namespaces` is set to `nil`' do
      Sidekiq::Cron.configuration.available_namespaces = nil
      # new jobs!
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace1'))
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace2'))

      assert_equal %w[default], Sidekiq::Cron::Namespace.all
    end

    it 'returns all the existing namespaces if `available_namespaces` is set to `auto`' do
      Sidekiq::Cron.configuration.available_namespaces = :auto
      # new jobs!
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace1'))
      Sidekiq::Cron::Job.create(args.merge(namespace: 'namespace2'))

      assert_equal %w[default namespace1 namespace2], Sidekiq::Cron::Namespace.all.sort
    end

    it 'uses provided namespaces list if available' do
      Sidekiq::Cron.configuration.available_namespaces = %w[namespace1 namespace2]

      Sidekiq::Cron::Job.create(args.merge(namespace: 'implicit-namespace1'))
      Sidekiq::Cron::Job.create(args.merge(namespace: 'implicit-namespace2'))

      assert_equal %w[default namespace1 namespace2], Sidekiq::Cron::Namespace.all.sort
    end

    it 'raises `ArgumentError` if unexpected `available_namespaces` value was provided' do
      Sidekiq::Cron.configuration.available_namespaces = 42

      assert_raises(ArgumentError) do
        Sidekiq::Cron::Namespace.all
      end
    end
  end

  describe 'count' do
    it 'returns the jobs count per namespaces' do
      Sidekiq::Cron.configuration.available_namespaces = %w[namespace1 namespace2]

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
      Sidekiq::Cron.configuration.available_namespaces = %w[namespace1 namespace2]
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

      assert_equal expected, counts
    end
  end
end
