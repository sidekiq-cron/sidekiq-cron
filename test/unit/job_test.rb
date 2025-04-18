# frozen_string_literal: true

require './test/test_helper'

describe "Cron Job" do
  before do
    Sidekiq::Cron.reset!

    Sidekiq::Cron.configuration.available_namespaces = :auto

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

  it "be initialized" do
    job = Sidekiq::Cron::Job.new()
    assert_nil job.last_enqueue_time
    assert job.is_a?(Sidekiq::Cron::Job)
  end

  describe "class methods" do
    it "have create method" do
      assert_respond_to Sidekiq::Cron::Job, :create
    end

    it "have destroy method" do
      assert_respond_to Sidekiq::Cron::Job, :destroy
    end

    it "have count" do
      assert_respond_to Sidekiq::Cron::Job, :count
    end

    it "have all" do
      assert_respond_to Sidekiq::Cron::Job, :all
    end

    it "have find" do
      assert_respond_to Sidekiq::Cron::Job, :find
    end
  end

  describe "instance methods" do
    before do
      @job = Sidekiq::Cron::Job.new()
    end

    it "have save method" do
      assert_respond_to @job, :save
    end

    it "have valid? method" do
      assert_respond_to @job, "valid?".to_sym
    end

    it "have destroy method" do
      assert_respond_to @job, :destroy
    end

    it "have enabled? method" do
      assert_respond_to @job, :enabled?
    end

    it "have disabled? method" do
      assert_respond_to @job, :disabled?
    end

    it 'have sort_name - used for sorting enabled disabled jobs on frontend' do
      job = Sidekiq::Cron::Job.new(name: "TestName")
      assert_equal job.sort_name, "0_testname"
    end
  end

  describe "invalid job" do
    before do
      @job = Sidekiq::Cron::Job.new()
    end

    it "allow a class instance for the klass" do
      @job.klass = CronTestClass

      refute @job.valid?
      refute @job.errors.any?{|e| e.include?("klass")}, "Should not have error for klass"
    end

    it "return false on valid? and errors" do
      refute @job.valid?
      assert @job.errors.is_a?(Array)

      assert @job.errors.any?{|e| e.include?("name")}, "Should have error for name"
      assert @job.errors.any?{|e| e.include?("cron")}, "Should have error for cron"
      assert @job.errors.any?{|e| e.include?("klass")}, "Should have error for klass"
    end

    it "return false on valid? with invalid cron" do
      @job.cron = "* s *"
      refute @job.valid?
      assert @job.errors.is_a?(Array)
      assert @job.errors.any?{|e| e.include?("cron")}, "Should have error for cron"
    end

    it "return false for valid? when namespace is '*'" do
      @job.namespace = "*"
      refute @job.valid?
      assert @job.errors.is_a?(Array)
      assert @job.errors.any?{|e| e.include?("namespace")}, "Should have error for namespace"
    end

    it "is invalid when parsing multiple cron lines in strict mode" do
      @job.cron = "every Wednesday at 5:30 and 6:45"
      @job.name = "example job"
      @job.klass = "ExampleJob"
      assert @job.valid?

      Sidekiq::Cron.configuration.natural_cron_parsing_mode = :strict

      refute @job.valid?
      assert @job.errors.is_a?(Array)
      assert @job.errors.any?{|e| e.include?("cron")}, "Should have error for cron"
    ensure
      Sidekiq::Cron.configuration.natural_cron_parsing_mode = :single
    end

    it "return false on save" do
      refute @job.save
    end
  end

  describe "new" do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *"
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it "have all set attributes" do
      @args.each do |key, value|
        assert_equal @job.send(key), value, "New job should have #{key} with value #{value} but it has: #{@job.send(key)}"
      end
    end

    it "have to_hash method" do
      [:name,:klass,:cron,:description,:source,:args,:message,:status].each do |key|
        assert @job.to_hash.has_key?(key), "to_hash must have key: #{key}"
      end
    end

    it "warns about unexpected namespace and fallbacks to default one" do
      Sidekiq::Cron.configuration.available_namespaces = %w[namespace1 namespace2]

      output = capture_logging(level: Logger::Severity::WARN) do
        @job = Sidekiq::Cron::Job.new(@args.merge(namespace: "namespace"))
      end

      assert_equal "default", @job.namespace
      assert_match(/WARN -- : Cron Jobs - unexpected namespace namespace encountered. Assigning to default namespace./, output)
    end

    it "does not warn on assigning default namespace which is not listed in `available_namespaces`" do
      Sidekiq::Cron.configuration.available_namespaces = %w[namespace1 namespace2]

      output = capture_logging(level: Logger::Severity::WARN) do
        @job = Sidekiq::Cron::Job.new(@args.merge(namespace: "default"))
      end

      assert_equal "default", @job.namespace

      assert_equal "", output
    end
  end

  describe 'cron formats' do
    before do
      @args = {
        name: "Test",
        klass: "CronTestClass"
      }
    end

    it 'should support natural language format' do
      @args[:cron] = "every 3 hours"
      @job = Sidekiq::Cron::Job.new(@args)
      assert @job.valid?
      assert_equal Fugit::Cron.new("0 */3 * * *"), @job.send(:parsed_cron)
    end

    it "should suppport cron format in strict mode" do
      Sidekiq::Cron.configuration.natural_cron_parsing_mode = :strict

      @args[:cron] = "55 * * * *"
      @job = Sidekiq::Cron::Job.new(@args)
      assert @job.valid?
      assert_equal Fugit::Cron.new("55 * * * *"), @job.send(:parsed_cron)
    ensure
      Sidekiq::Cron.configuration.natural_cron_parsing_mode = :single
    end

    it "should suppport natural language format in strict mode" do
      Sidekiq::Cron.configuration.natural_cron_parsing_mode = :strict

      @args[:cron] = "every 3 hours"
      @job = Sidekiq::Cron::Job.new(@args)
      assert @job.valid?
      assert_equal Fugit::Cron.new("0 */3 * * *"), @job.send(:parsed_cron)
    ensure
      Sidekiq::Cron.configuration.natural_cron_parsing_mode = :single
    end
  end

  describe 'parse_enqueue_time' do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *"
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should correctly parse new format' do
      assert_equal @job.send(:parse_enqueue_time, '2017-01-02 15:23:43 UTC'), Time.new(2017, 1, 2, 15, 23, 43, '+00:00')
    end

    it 'should correctly parse new format with different timezone' do
      assert_equal @job.send(:parse_enqueue_time, '2017-01-02 15:23:43 +01:00'), Time.new(2017, 1, 2, 15, 23, 43, '+01:00')
    end

    it 'should correctly parse old format' do
      assert_equal @job.send(:parse_enqueue_time, '2017-01-02 15:23:43'), Time.new(2017, 1, 2, 15, 23, 43, '+00:00')
    end
  end

  describe 'formatted time' do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *"
      }
      @job = Sidekiq::Cron::Job.new(@args)
      @time = Time.new(2015, 1, 2, 3, 4, 5, '+01:00')
    end

    it 'returns formatted_last_time' do
      assert_equal '2015-01-02T02:04:00Z', @job.formatted_last_time(@time)
    end

    it 'returns formatted_enqueue_time' do
      assert_equal '1420164240.0', @job.formatted_enqueue_time(@time)
    end
  end

  describe "new with different class inputs" do
    it "be initialized by 'klass' and Class" do
      job = Sidekiq::Cron::Job.new('klass' => CronTestClass)
      assert_equal job.message['class'], 'CronTestClass'
    end

    it "be initialized by 'klass' and string Class" do
      job = Sidekiq::Cron::Job.new('klass' => 'CronTestClass')
      assert_equal job.message['class'], 'CronTestClass'
    end

    it "be initialized by 'class' and string Class" do
      job = Sidekiq::Cron::Job.new('class' => 'CronTestClass')
      assert_equal job.message['class'], 'CronTestClass'
    end

    it "be initialized by 'class' and Class" do
      job = Sidekiq::Cron::Job.new('class' => CronTestClass)
      assert_equal job.message['class'], 'CronTestClass'
    end
  end

  describe "new should find klass specific settings (queue, retry ...)" do
    it "nothing raise on unknown klass" do
      job = Sidekiq::Cron::Job.new('klass' => 'UnknownCronClass')
      assert_equal job.message, {"class"=>"UnknownCronClass", "args"=>[], "queue"=>"default"}
    end

    it "be initialized with default attributes" do
      job = Sidekiq::Cron::Job.new('klass' => 'CronTestClass')
      assert_equal job.message, {"retry"=>true, "queue"=>"default", "class"=>"CronTestClass", "args"=>[]}
    end

    it "be initialized with class specified attributes" do
      job = Sidekiq::Cron::Job.new('class' => 'CronTestClassWithQueue')
      assert_equal job.message, {"retry"=>false,
                                 "queue"=>:super,
                                 "backtrace"=>true,
                                 "class"=>"CronTestClassWithQueue",
                                 "args"=>[]}
    end

    it "be initialized with 'class' and overwrite queue by settings" do
      job = Sidekiq::Cron::Job.new('class' => CronTestClassWithQueue, queue: 'my_testing_queue')

      assert_equal job.message, {"retry"=>false,
                                 "queue"=>'my_testing_queue',
                                 "backtrace"=>true,
                                 "class"=>"CronTestClassWithQueue",
                                 "args"=>[]}
    end

    it "be initialized with 'class' and overwrite retry by settings" do
      job = Sidekiq::Cron::Job.new('class' => CronTestClassWithQueue, retry: 5)

      assert_equal job.message, {"retry"=>5,
                                 "queue"=>:super,
                                 "backtrace"=>true,
                                 "class"=>"CronTestClassWithQueue",
                                 "args"=>[]}

      job = Sidekiq::Cron::Job.new('class' => CronTestClass, retry: false)

      assert_equal job.message, {"retry"=>false,
                                 "queue"=>"default",
                                 "class"=>"CronTestClass",
                                 "args"=>[]}
    end

    it "be initialized with 'class' and date_as_argument" do
      job = Sidekiq::Cron::Job.new('class' => 'CronTestClassWithQueue', "date_as_argument" => true)

      job_message = job.message
      job_args    = job_message.delete("args")
      assert_equal job_message, {"retry"=>false,
                                 "queue"=>:super,
                                 "backtrace"=>true,
                                 "class"=>"CronTestClassWithQueue"}
      assert_empty job_args

      enqueue_args = job.enqueue_args
      assert enqueue_args[-1].is_a?(Float)
      assert enqueue_args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
    end

    it "be initialized with 'class', 2 arguments and date_as_argument" do
      job = Sidekiq::Cron::Job.new('class' => 'CronTestClassWithQueue', "date_as_argument" => true, "args"=> ["arg1", :arg2])

      job_message = job.message
      job_args    = job_message.delete("args")
      assert_equal job_message, {"retry"=>false,
                                 "queue"=>:super,
                                 "backtrace"=>true,
                                 "class"=>"CronTestClassWithQueue"}
      assert_equal job_args, ["arg1", :arg2]

      enqueue_args = job.enqueue_args
      assert_equal enqueue_args[0..-2], ["arg1", :arg2]
      assert enqueue_args[-1].is_a?(Float)
      assert enqueue_args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
    end

    describe "when job is Active Job worker class" do
      it "be initialized with default attributes" do
        job = Sidekiq::Cron::Job.new('klass' => 'ActiveJobCronTestClass')
        assert_equal job.message, {"queue"=>"default", "class"=>"ActiveJobCronTestClass", "args"=>[]}
      end

      it "be initialized with class specified attributes" do
        job = Sidekiq::Cron::Job.new('class' => 'ActiveJobCronTestClassWithQueue')
        assert_equal job.message, {"queue"=>"super", "class"=>"ActiveJobCronTestClassWithQueue", "args"=>[]}
      end
    end
  end

  describe "cron test" do
    before do
      @job = Sidekiq::Cron::Job.new()
    end

    it "return previous minute" do
      @job.cron = "* * * * *"
      time = Time.new(2018, 8, 10, 13, 24, 56).utc
      assert_equal @job.last_time(time).strftime("%Y-%m-%d-%H-%M-%S"), time.strftime("%Y-%m-%d-%H-%M-00")
    end

    it "return previous hour" do
      @job.cron = "1 * * * *"
      time = Time.new(2018, 8, 10, 13, 24, 56).utc
      assert_equal @job.last_time(time).strftime("%Y-%m-%d-%H-%M-%S"), time.strftime("%Y-%m-%d-%H-01-00")
    end

    it "return previous day" do
      @job.cron = "1 2 * * * Etc/GMT"
      time = Time.new(2018, 8, 10, 13, 24, 56).utc

      if time.hour >= 2
        assert_equal @job.last_time(time).strftime("%Y-%m-%d-%H-%M-%S"), time.strftime("%Y-%m-%d-02-01-00")
      else
        yesterday = time - 1.day
        assert_equal @job.last_time(time).strftime("%Y-%m-%d-%H-%M-%S"), yesterday.strftime("%Y-%m-%d-02-01-00")
      end
    end
  end

  describe 'handling date_as_argument' do
    before do
      @args = {
        name: 'Test',
        cron: '* * * * *',
        queue: 'default',
        klass: 'CronTestClass'
      }
    end

    it 'sets date_as_argument to true' do
      Sidekiq::Cron::Job.create(@args.merge(date_as_argument: true))
      stored_job = Sidekiq::Cron::Job.find(@args[:name])
      assert stored_job.date_as_argument?
    end

    it 'sets date_as_argument to false' do
      Sidekiq::Cron::Job.create(@args.merge(date_as_argument: false))
      stored_job = Sidekiq::Cron::Job.find(@args[:name])
      refute stored_job.date_as_argument?
    end

    it 'updates date_as_argument from true to false' do
      Sidekiq::Cron::Job.create(@args.merge(date_as_argument: true))
      stored_job = Sidekiq::Cron::Job.find(@args[:name])
      assert stored_job.date_as_argument?

      Sidekiq::Cron::Job.create(@args.merge(date_as_argument: false))
      stored_job = Sidekiq::Cron::Job.find(@args[:name])
      refute stored_job.date_as_argument?
    end

    it 'updates date_as_argument from false to true' do
      Sidekiq::Cron::Job.create(@args.merge(date_as_argument: false))
      stored_job = Sidekiq::Cron::Job.find(@args[:name])
      refute stored_job.date_as_argument?

      Sidekiq::Cron::Job.create(@args.merge(date_as_argument: true))
      stored_job = Sidekiq::Cron::Job.find(@args[:name])
      assert stored_job.date_as_argument?
    end
  end

  describe '#sidekiq_worker_message' do
    before do
      @args = {
        name:  'Test',
        cron:  '* * * * *',
        queue: 'super_queue',
        klass: 'CronTestClass',
        args:  { foo: 'bar' }
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should return valid payload for Sidekiq::Client' do
      payload = {
        "retry" => true,
        "queue" => "super_queue",
        "class" => "CronTestClass",
        "args"  => [{:foo=>"bar"}]
      }
      assert_equal @job.sidekiq_worker_message, payload
    end

    describe 'with date_as_argument' do
      before do
        @args[:date_as_argument] = true
        @job = Sidekiq::Cron::Job.new(@args)
      end

      let(:args) { @job.sidekiq_worker_message['args'] }

      it 'should add timestamp to args' do
        assert_equal args[0], {foo: 'bar'}
        assert args[-1].is_a?(Float)
        assert args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
      end
    end

    describe 'with GlobalID::Identification args' do
      before do
        @args[:args] = Person.new(1)
        @job = Sidekiq::Cron::Job.new(@args)
      end

      let(:args) { @job.sidekiq_worker_message['args'] }

      it 'should add timestamp to args' do
        assert_equal args[0], Person.new(1)
      end
    end

    describe 'with GlobalID::Identification args in Array' do
      before do
        @args[:args] = [Person.new(1)]
        @job = Sidekiq::Cron::Job.new(@args)
      end

      let(:args) { @job.sidekiq_worker_message['args'] }

      it 'should add timestamp to args' do
        assert_equal args[0], Person.new(1)
      end
    end

    describe 'with GlobalID::Identification args in Hash' do
      before do
        @args[:args] = {person: Person.new(1)}
        @job = Sidekiq::Cron::Job.new(@args)
      end

      let(:args) { @job.sidekiq_worker_message['args'] }

      it 'should add timestamp to args' do
        assert_equal args[0], {person: Person.new(1)}
      end
    end
  end

  describe '#sidekiq_worker_message settings overwrite queue name' do
    before do
      @args = {
        name:  'Test',
        cron:  '* * * * *',
        queue: 'super_queue',
        klass: 'CronTestClassWithQueue',
        args:  { foo: 'bar' }
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should return valid payload for Sidekiq::Client with overwrite queue name' do
      payload = {
        "retry" => false,
        "backtrace"=>true,
        "queue" => "super_queue",
        "class" => "CronTestClassWithQueue",
        "args"  => [{:foo=>"bar"}]
      }
      assert_equal @job.sidekiq_worker_message, payload
    end
  end

  describe '#sidekiq_worker_message settings overwrite retry name' do
    before do
      @args = {
        name:  'Test',
        cron:  '* * * * *',
        retry: 5,
        klass: 'CronTestClassWithQueue',
        args:  { foo: 'bar' }
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should return valid payload for Sidekiq::Client with overwrite retry' do
      payload = {
        "retry" => 5,
        "backtrace" => true,
        "queue" => :super,
        "class" => "CronTestClassWithQueue",
        "args"  => [{:foo=>"bar"}]
      }
      assert_equal @job.sidekiq_worker_message, payload
    end
  end

  describe '#active_job_message' do
    before do
      SecureRandom.stubs(:uuid).returns('XYZ')
      ::ActiveJob::Base.queue_name_prefix = ''

      @args = {
        name:  'Test',
        cron:  '* * * * *',
        klass: 'ActiveJobCronTestClass',
        queue: 'super_queue',
        description: nil,
        args:  { foo: 'bar' }
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should return valid payload for Sidekiq::Client' do
      payload = {
        'class'       => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped'     => 'ActiveJobCronTestClass',
        'queue'       => 'super_queue',
        'description' => nil,
        'args'        => [{
          'job_class'  => 'ActiveJobCronTestClass',
          'job_id'     => 'XYZ',
          'queue_name' => 'super_queue',
          'arguments'  => [{foo: 'bar'}]
        }]
      }
      assert_equal @job.active_job_message, payload
    end

    describe 'with date_as_argument' do
      before do
        @args[:date_as_argument] = true
        @job = Sidekiq::Cron::Job.new(@args)
      end

      let(:args) { @job.active_job_message['args'][0]['arguments'] }

      it 'should add timestamp to args' do
        args = @job.active_job_message['args'][0]['arguments']
        assert_equal args[0], {foo: 'bar'}
        assert args[-1].is_a?(Float)
        assert args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
      end
    end
  end

  describe '#active_job_message - unknown Active Job Worker class' do
    before do
      SecureRandom.stubs(:uuid).returns('XYZ')
      ::ActiveJob::Base.queue_name_prefix = ''

      @args = {
        name:  'Test',
        cron:  '* * * * *',
        klass: 'UnknownActiveJobCronTestClass',
        active_job: true,
        queue: 'super_queue',
        description: nil,
        args:  { foo: 'bar' }
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should return valid payload for Sidekiq::Client' do
      payload = {
        'class'       => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped'     => 'UnknownActiveJobCronTestClass',
        'queue'       => 'super_queue',
        'description' => nil,
        'args'        => [{
          'job_class'  => 'UnknownActiveJobCronTestClass',
          'job_id'     => 'XYZ',
          'queue_name' => 'super_queue',
          'arguments'  => [{foo: 'bar'}]
        }]
      }
      assert_equal @job.active_job_message, payload
    end
  end

  describe '#active_job_message with symbolize_args (hash)' do
    before do
      SecureRandom.stubs(:uuid).returns('XYZ')
      ::ActiveJob::Base.queue_name_prefix = ''

      @args = {
        name:  'Test',
        cron:  '* * * * *',
        klass: 'ActiveJobCronTestClass',
        queue: 'super_queue',
        description: nil,
        symbolize_args: true,
        args: { 'foo' => 'bar' }
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should return valid payload for Sidekiq::Client' do
      payload = {
        'class'       => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped'     => 'ActiveJobCronTestClass',
        'queue'       => 'super_queue',
        'description' => nil,
        'args'        => [{
          'job_class'  => 'ActiveJobCronTestClass',
          'job_id'     => 'XYZ',
          'queue_name' => 'super_queue',
          'arguments'  => [{foo: 'bar'}]
        }]
      }
      assert_equal @job.active_job_message, payload
    end
  end

  describe '#active_job_message with symbolize_args (array)' do
    before do
      SecureRandom.stubs(:uuid).returns('XYZ')
      ::ActiveJob::Base.queue_name_prefix = ''

      @args = {
        name:  'Test',
        cron:  '* * * * *',
        klass: 'ActiveJobCronTestClass',
        queue: 'super_queue',
        description: nil,
        symbolize_args: true,
        args: [{ 'foo' => 'bar' }]
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it 'should return valid payload for Sidekiq::Client' do
      payload = {
        'class'       => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped'     => 'ActiveJobCronTestClass',
        'queue'       => 'super_queue',
        'description' => nil,
        'args'        => [{
          'job_class'  => 'ActiveJobCronTestClass',
          'job_id'     => 'XYZ',
          'queue_name' => 'super_queue',
          'arguments'  => [{foo: 'bar'}]
        }]
      }
      assert_equal @job.active_job_message, payload
    end
  end

  describe '#active_job_message with queue_name_prefix' do
    before do
      SecureRandom.stubs(:uuid).returns('XYZ')
      @original_queue_name_prefix = ::ActiveJob::Base.queue_name_prefix
      ::ActiveJob::Base.queue_name_prefix = "prefix"

      @args = {
        name:  'Test',
        cron:  '* * * * *',
        klass: 'ActiveJobCronTestClass',
        queue: 'super_queue',
        queue_name_prefix: 'prefix',
        args:  { foo: 'bar' }
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    after do
      ::ActiveJob::Base.queue_name_prefix = @original_queue_name_prefix
    end

    it 'should return valid payload for Sidekiq::Client' do
      payload = {
        'class'       => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped'     => 'ActiveJobCronTestClass',
        'queue'       => 'prefix_super_queue',
        'description' => nil,
        'args'        => [{
          'job_class'  => 'ActiveJobCronTestClass',
          'job_id'     => 'XYZ',
          'queue_name' => 'prefix_super_queue',
          'arguments'  => [{foo: 'bar'}]
        }]
      }
      assert_equal @job.active_job_message, payload
    end
  end

  describe '#enqueue!' do
    describe 'active job' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'ActiveJobCronTestClass'
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message' do
        @job.expects(:enqueue_active_job)
            .returns(ActiveJobCronTestClass.new)
        @job.enqueue!
      end

      describe 'with date_as_argument' do
        before do
          @args[:date_as_argument] = true
          @job = Sidekiq::Cron::Job.new(@args)
        end

        it 'should add timestamp to args' do
          job = ActiveJobCronTestClass.new

          ActiveJobCronTestClass.expects(:set)
                                .returns(job)
                                .with { |**args|
                                  assert_equal 'default', args[:queue]
                                }

          job.expects(:perform_later)
             .returns(job)
             .with { |*args|
               assert args[-1].is_a?(Float)
               assert args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
             }

          @job.enqueue!
        end
      end

      describe 'with active_job == true' do
        before do
          @args.merge!(active_job: true)
        end

        describe 'with active_job job class' do
          before do
            @job = Sidekiq::Cron::Job.new(@args.merge(klass: 'ActiveJobCronTestClass'))
          end

          it 'enques via active_job interface' do
            @job.expects(:enqueue_active_job)
                .returns(ActiveJobCronTestClass.new)
            @job.enqueue!
          end
        end

        describe 'with non sidekiq job class' do
          before do
            @job = Sidekiq::Cron::Job.new(@args.merge(klass: 'ActiveJobCronTestClass'))
          end

          it 'enques via active_job interface' do
            @job.expects(:enqueue_active_job)
                .returns(ActiveJobCronTestClass.new)
            @job.enqueue!
          end
        end
      end
    end

    describe 'active job with queue_name_prefix' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'ActiveJobCronTestClass',
          queue: 'cron'
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message with queue_name_prefix' do
        @job.expects(:enqueue_active_job)
            .returns(ActiveJobCronTestClass.new)
        @job.enqueue!
      end
    end

    describe 'active job via configuration (bool: true) [unknown class]' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'UnknownClass',
          active_job: true
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message' do
        @job.expects(:active_job_message)
          .returns('class' => 'UnknownClass', 'args' => [])
        @job.enqueue!
      end
    end

    describe 'active job via configuration (string: true) [unknown class]' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'UnknownClass',
          active_job: 'true'
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message' do
        @job.expects(:active_job_message)
          .returns('class' => 'UnknownClass', 'args' => [])
        @job.enqueue!
      end
    end

    describe 'active job via configuration (string: yes) [unknown class]' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'UnknownClass',
          active_job: 'yes'
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message' do
        @job.expects(:active_job_message)
          .returns('class' => 'UnknownClass', 'args' => [])
        @job.enqueue!
      end
    end

    describe 'active job via configuration (number: 1) [unknown class]' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'UnknownClass',
          active_job: 1
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message' do
        @job.expects(:active_job_message)
          .returns('class' => 'UnknownClass', 'args' => [])
        @job.enqueue!
      end
    end

    describe 'active job via configuration with queue_name_prefix option [unknown class]' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'UnknownClass',
          queue: 'cron',
          active_job: true,
          queue_name_prefix: 'prefix'
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message with queue_name_prefix' do
        @job.expects(:active_job_message)
          .returns('class' => 'UnknownClass', 'args' => [], 'queue' => 'prefix_cron')
        @job.enqueue!
      end
    end

    describe 'sidekiq worker' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'CronTestClass'
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue active jobs message' do
        @job.expects(:enqueue_sidekiq_worker)
            .returns(true)
        @job.enqueue!
      end

      describe 'with date_as_argument' do
        before do
          @args[:date_as_argument] = true
          @job = Sidekiq::Cron::Job.new(@args)
        end

        it 'should add timestamp to args' do
          CronTestClass::Setter.any_instance
                               .expects(:perform_async)
                               .returns(true)
                               .with { |*args|
                                 assert args[-1].is_a?(Float)
                                 assert args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
                               }
          @job.enqueue!
        end
      end
    end

    describe 'sidekiq worker unknown class' do
      before do
        @args = {
          name:  'Test',
          cron:  '* * * * *',
          klass: 'UnknownClass',
          queue: 'another'
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      it 'pushes to queue sidekiq worker message' do
        @job.expects(:sidekiq_worker_message)
            .returns('class' => 'UnknownClass', 'args' => [], 'queue' => 'another')
        @job.enqueue!
      end
    end
  end

  describe "save" do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
      @job = Sidekiq::Cron::Job.new(@args)
    end

    it "be saved" do
      assert @job.save
    end

    it "be saved and found by name" do
      assert @job.save, "not saved"
      assert Sidekiq::Cron::Job.find("Test").is_a?(Sidekiq::Cron::Job)
    end
  end

  describe "nonexisting job" do
    it "not be found" do
      assert_nil Sidekiq::Cron::Job.find("nonexisting"), "should return nil"
    end
  end

  describe "disabled/enabled" do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
    end

    it "be created and enabled" do
      Sidekiq::Cron::Job.create(@args)
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "enabled"
    end

    it "be created and then enabled and disabled" do
      Sidekiq::Cron::Job.create(@args)
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "enabled"

      job.enable!
      assert_equal job.status, "enabled"

      job.disable!
      assert_equal job.status, "disabled"
    end

    it "be created with status disabled" do
      Sidekiq::Cron::Job.create(@args.merge(status: "disabled"))
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "disabled"
      assert_equal job.disabled?, true
      assert_equal job.enabled?, false
    end

    it "be created with status enabled and disable it afterwards" do
      Sidekiq::Cron::Job.create(@args)
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "enabled"
      assert_equal job.enabled?, true
      job.disable!
      assert_equal job.status, "disabled", "directly after call"
      assert_equal job.disabled?, true
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "disabled", "after find"
    end

    it "status shouldn't be rewritten after save without status" do
      Sidekiq::Cron::Job.create(@args)
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "enabled"
      job.disable!
      assert_equal job.status, "disabled", "directly after call"
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "disabled", "after find"

      Sidekiq::Cron::Job.create(@args)
      assert_equal job.status, "disabled", "after second create"
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.status, "disabled", "after second find"
    end

    it "last_enqueue_time shouldn't be rewritten after save" do
      # Adding last_enqueue_time to initialize is only for testing purposes.
      last_enqueue_time = '2013-01-01 23:59:59 +0000'
      expected_enqueue_time = DateTime.parse(last_enqueue_time).to_time.utc
      Sidekiq::Cron::Job.create(@args.merge('last_enqueue_time' => last_enqueue_time))
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.last_enqueue_time, expected_enqueue_time

      Sidekiq::Cron::Job.create(@args)
      job = Sidekiq::Cron::Job.find(@args)
      assert_equal job.last_enqueue_time, expected_enqueue_time, "after second create should have same time"
    end
  end

  describe "initialize args" do
    it "from JSON" do
      args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass",
        args: JSON.dump(["123"])
      }
      Sidekiq::Cron::Job.new(args).tap do |job|
        assert_equal job.args, ["123"]
        assert_equal job.name, "Test"
      end
    end

    it "from String" do
      args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass",
        args: "(my funny string)"
      }
      Sidekiq::Cron::Job.new(args).tap do |job|
        assert_equal job.args, ["(my funny string)"]
        assert_equal job.name, "Test"
      end
    end

    it "from Array" do
      args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass",
        args: ["This is array"]
      }
      Sidekiq::Cron::Job.new(args).tap do |job|
        assert_equal job.args, ["This is array"]
        assert_equal job.name, "Test"
      end
    end

    it "from GlobalID::Identification" do
      args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass",
        args: Person.new(1)
      }
      Sidekiq::Cron::Job.new(args).tap do |job|
        assert_equal job.args, [{"_sc_globalid"=>"gid://app/Person/1"}]
      end
    end

    it "from GlobalID::Identification in Array" do
      args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass",
        args: [Person.new(1)]
      }
      Sidekiq::Cron::Job.new(args).tap do |job|
        assert_equal job.args, [{"_sc_globalid"=>"gid://app/Person/1"}]
      end
    end

    it "from GlobalID::Identification in Hash" do
      args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass",
        args: {person: Person.new(1)}
      }
      Sidekiq::Cron::Job.new(args).tap do |job|
        assert_equal job.args, [{person: {"_sc_globalid"=>"gid://app/Person/1"}}]
      end
    end
  end

  describe 'with jobs in and out of namespaces' do
    let(:custom_namespace) { 'my-custom-namespace' }

    let(:no_namespace_to_hash) do
      {
        name: 'no-namespace-test-job',
        klass: 'NoNamespaceCronTestClass',
        cron: '* * * * *',
        description: '',
        args: '[]',
        message: '{}',
        status: 'enabled',
        active_job: '1',
        queue_name_prefix: nil,
        queue_name_delimiter: nil,
        last_enqueue_time: nil,
        symbolize_args: '0'
      }
    end

    before do
      # A job created without a namespace, like it would have been prior to
      # namespaces implementation.
      Sidekiq.redis do |conn|
        conn.sadd 'cron_jobs', 'cron_job:no-namespace-job'
        conn.hset 'cron_job:no-namespace-job',
                  (no_namespace_to_hash.transform_values! { |v| v || '' })
      end

      # A job in the 'default' namespace
      Sidekiq::Cron::Job.create(
        name: 'DefaultJob',
        cron: '* * * * *',
        klass: 'CronTestClass'
      )

      # A job in a custom namespace
      Sidekiq::Cron::Job.create(
        name: 'CustomJob',
        cron: '* * * * *',
        klass: 'CronTestClass',
        namespace: custom_namespace
      )

      Sidekiq::Cron::Job.migrate_old_jobs_if_needed!
    end

    describe 'all' do
      describe 'when passing nil' do
        it 'should return jobs from the default namespace' do
          assert_equal 2,
                       Sidekiq::Cron::Job.all(nil).size,
                       'all(nil) should have returned 2 jobs : one from the ' \
                       'default namespace and one out of any namespaces'
          assert_equal Sidekiq::Cron::Job.all(nil).collect(&:namespace).uniq.first,
                       'default',
                       'All the jobs returned by all(nil) should have the "default" namespace'
        end
      end

      describe 'when passing a blank string' do
        it 'should return jobs from the default namespace' do
          assert_equal 2,
                       Sidekiq::Cron::Job.all('').size,
                       "all('') should have returned 2 jobs : one from the " \
                       'default namespace and one out of any namespaces'
          assert_equal Sidekiq::Cron::Job.all('').collect(&:namespace).uniq.first,
                       'default',
                       'All the jobs returned by all(nil) should have the "default" namespace'
        end
      end

      describe 'when passing no arguments' do
        it 'should return jobs from the default namespace' do
          assert_equal 2,
                       Sidekiq::Cron::Job.all.size,
                       'all() should have returned 2 jobs : one from the ' \
                       'default namespace and one out of any namespaces'
          assert_equal Sidekiq::Cron::Job.all.collect(&:namespace).uniq.first,
                       'default',
                       'All the jobs returned by all(nil) should have the "default" namespace'
        end
      end

      describe 'when passing a namespace' do
        it 'should return jobs from the default namespace' do
          assert_equal Sidekiq::Cron::Job.all(custom_namespace).size, 1, 'Should have 1 job'
          assert_equal Sidekiq::Cron::Job.all(custom_namespace).first.namespace,
                       custom_namespace,
                       "all(#{custom_namespace.inspect}) should have returned " \
                       'jobs from the default namespace'
        end
      end

      describe "when passing a namespace which doesn't exist" do
        it 'should return jobs from the default namespace' do
          assert_equal Sidekiq::Cron::Job.all('rammstein').size, 0, 'Should have 0 jobs'
        end
      end

      describe 'when passing an asterisk' do
        it 'should return all the existing jobs from all namespaces and out of a namespace' do
          assert_equal Sidekiq::Cron::Job.all('*').size, 3, 'Should have 3 jobs'
        end
      end

      describe 'with explicitly provided available namespaces' do
        it 'should return all the jobs only from available namespaces' do
          Sidekiq::Cron.configuration.available_namespaces = %w[default]
          assert_equal 2, Sidekiq::Cron::Job.all('*').size, 'Should have 2 jobs'

          Sidekiq::Cron.configuration.available_namespaces = [custom_namespace]
          assert_equal 3, Sidekiq::Cron::Job.all('*').size, 'Should have 3 job'
        end
      end
    end

    describe 'count' do
      describe 'when passing nil' do
        it 'should return jobs count from the default namespace' do
          assert_equal 2,
                       Sidekiq::Cron::Job.count(nil),
                       'count(nil) should have returned 2 (one for the job ' \
                       'from the default namespace and one for the job out ' \
                       'of any namespaces)'
        end
      end

      describe 'when passing a blank string' do
        it 'should return jobs count from the default namespace' do
          assert_equal 2,
                       Sidekiq::Cron::Job.count(''),
                       "count('') should have returned 2 (one for the job " \
                       'from the default namespace and one for the job out ' \
                       'of any namespaces)'
        end
      end

      describe 'when passing no arguments' do
        it 'should return jobs count from the default namespace' do
          assert_equal 2,
                       Sidekiq::Cron::Job.count,
                       'count() should have returned 2 (one for the job ' \
                       'from the default namespace and one for the job out ' \
                       'of any namespaces)'
        end
      end

      describe 'when passing a namespace' do
        it 'should return jobs count from the passed namespace' do
          assert_equal 1,
                       Sidekiq::Cron::Job.count(custom_namespace),
                       'Should have 1 job'
        end
      end

      describe "when passing a namespace which doesn't exist" do
        it 'should return jobs count of 0' do
          assert_equal 0,
                       Sidekiq::Cron::Job.count('rammstein'),
                       'Should have 0 jobs'
        end
      end

      describe 'when passing an asterisk' do
        it 'should return the jobs count from all namespaces and out of any namespaces' do
          assert_equal 3,
                       Sidekiq::Cron::Job.count('*'),
                       'Should have 3 jobs'
        end
      end
    end
  end

  describe "create & find methods" do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
    end

    it "create first three jobs" do
      assert_equal Sidekiq::Cron::Job.count, 0, "Should have 0 jobs"
      Sidekiq::Cron::Job.create(@args)
      Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
      Sidekiq::Cron::Job.create(@args.merge(name: "Test3"))
      assert_equal Sidekiq::Cron::Job.count, 3, "Should have 3 jobs"
    end

    it "create first three jobs - 1 has same name" do
      assert_equal Sidekiq::Cron::Job.count, 0, "Should have 0 jobs"
      Sidekiq::Cron::Job.create(@args)
      Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
      Sidekiq::Cron::Job.create(@args.merge(cron: "1 * * * *"))
      assert_equal Sidekiq::Cron::Job.count, 2, "Should have 2 jobs"
    end

    it "be found by method all" do
      Sidekiq::Cron::Job.create(@args)
      Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
      Sidekiq::Cron::Job.create(@args.merge(name: "Test3"))
      assert_equal Sidekiq::Cron::Job.all.size, 3, "Should have 3 jobs"
      assert Sidekiq::Cron::Job.all.all?{|j| j.is_a?(Sidekiq::Cron::Job)}, "All returned jobs should be Job class"
    end

    it "be found by method all - defect in set" do
      Sidekiq::Cron::Job.create(@args)
      Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
      Sidekiq::Cron::Job.create(@args.merge(name: "Test3"))

      Sidekiq.redis do |conn|
        conn.sadd Sidekiq::Cron::Job.jobs_key, ["some_other_key"]
      end

      assert_equal Sidekiq::Cron::Job.all.size, 3, "All have to return only valid 3 jobs"
    end

    it "be found by string name" do
      Sidekiq::Cron::Job.create(@args)
      assert Sidekiq::Cron::Job.find("Test")
    end

    it "be found by hash with key name" do
      Sidekiq::Cron::Job.create(@args)
      assert Sidekiq::Cron::Job.find(name: "Test"), "symbol keys keys"

      Sidekiq::Cron::Job.create(@args)
      assert Sidekiq::Cron::Job.find('name' => "Test"), "String keys"
    end
  end

  describe "destroy" do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
    end

    it "create and then destroy by hash" do
      Sidekiq::Cron::Job.create(@args)
      assert_equal Sidekiq::Cron::Job.all.size, 1, "Should have 1 job"

      assert Sidekiq::Cron::Job.destroy(@args)
      assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 job after destroy"
    end

    it "return false on destroying nonexisting" do
      assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs"
      refute Sidekiq::Cron::Job.destroy("nonexisting")
    end

    it "return destroy by string name" do
      Sidekiq::Cron::Job.create(@args)
      assert Sidekiq::Cron::Job.destroy("Test")
    end

    it "return destroy by hash with key name" do
      Sidekiq::Cron::Job.create(@args)
      assert Sidekiq::Cron::Job.destroy(name: "Test"), "symbol keys keys"

      Sidekiq::Cron::Job.create(@args)
      assert Sidekiq::Cron::Job.destroy('name' => "Test"), "String keys"
    end
  end

  describe "destroy_removed_jobs only destroys non dynamic jobs" do
    before do
      args1 = {
        name: "WillBeErasedJob",
        cron: "* * * * *",
        klass: "CronTestClass",
        source: "schedule"
      }
      Sidekiq::Cron::Job.create(args1)

      args2 = {
        name: "ContinueRemainingScheduleJob",
        cron: "* * * * *",
        klass: "CronTestClass",
        source: "schedule"
      }
      Sidekiq::Cron::Job.create(args2)

      args2 = {
        name: "ContinueRemainingDynamicJob",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
      Sidekiq::Cron::Job.create(args2)
    end

    it "be destroyed removed job that not exists in args" do
      assert_equal Sidekiq::Cron::Job.destroy_removed_jobs(["ContinueRemainingScheduleJob"]), ["WillBeErasedJob"], "Should be destroyed WillBeErasedJob"
    end
  end

  describe "test of enqueue" do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
      # First time is always after next cron time!
      @time = Time.now.utc + 120
    end

    it "be always false when status is disabled" do
      refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enqueue? @time
      refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enqueue? @time - 60
      refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enqueue? @time - 120
      assert_equal Sidekiq::Queue.all.size, 0, "Sidekiq 0 queues"
    end

    it "be false for same times" do
      assert Sidekiq::Cron::Job.new(@args).should_enqueue?(@time), "First time - true"
      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time
      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time
    end

    it "be false for same times but true for next time" do
      assert Sidekiq::Cron::Job.new(@args).should_enqueue?(@time), "First time - true"
      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time
      assert Sidekiq::Cron::Job.new(@args).should_enqueue? @time + 135
      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time + 135
      assert Sidekiq::Cron::Job.new(@args).should_enqueue? @time + 235
      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time + 235

      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time
      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time + 135
      refute Sidekiq::Cron::Job.new(@args).should_enqueue? @time + 235
    end

    it "should not enqueue jobs that are past" do
      assert Sidekiq::Cron::Job.new(@args.merge(cron: "*/1 * * * *")).should_enqueue? @time
      refute Sidekiq::Cron::Job.new(@args.merge(cron: "0 1,13 * * *")).should_enqueue? @time
    end

    it "should enqueue jobs that are within reschedule grace period" do
      time = Time.new(2024, 4, 21, 12, 30, 0, "UTC")
      refute Sidekiq::Cron::Job.new(@args.merge(cron: "10 * * * *")).should_enqueue? time

      Sidekiq::Cron.configuration.stub(:reschedule_grace_period, 60 * 60) do
        assert Sidekiq::Cron::Job.new(@args.merge(cron: "10 * * * *")).should_enqueue? time
      end
    end

    it 'doesnt skip enqueuing if job is resaved near next enqueue time' do
      job = Sidekiq::Cron::Job.new(@args)
      assert job.test_and_enqueue_for_time!(@time), "should enqueue"

      future_now = @time + 1 * 60 * 60
      Time.stubs(:now).returns(future_now) # Save uses Time.now.utc
      job.save
      assert Sidekiq::Cron::Job.new(@args).test_and_enqueue_for_time!(future_now + 30), "should enqueue"
    end

    it "remove old enqueue times + should be enqeued" do
      job = Sidekiq::Cron::Job.new(@args)
      assert_nil job.last_enqueue_time
      assert job.test_and_enqueue_for_time!(@time), "should enqueue"
      assert job.last_enqueue_time

      refute Sidekiq::Cron::Job.new(@args).test_and_enqueue_for_time!(@time), "should not enqueue"
      Sidekiq.redis do |conn|
        assert_equal conn.zcard(Sidekiq::Cron::Job.new(@args).send(:job_enqueued_key)), 1, "Should have one enqueued job"
      end
      assert_equal Sidekiq::Queue.all.first.size, 1, "Sidekiq queue 1 job in queue"

      # 20 hours after.
      assert Sidekiq::Cron::Job.new(@args).test_and_enqueue_for_time! @time + 1 * 60 * 60
      refute Sidekiq::Cron::Job.new(@args).test_and_enqueue_for_time! @time + 1 * 60 * 60

      Sidekiq.redis do |conn|
        assert_equal conn.zcard(Sidekiq::Cron::Job.new(@args).send(:job_enqueued_key)), 2, "Should have two enqueued job"
      end
      assert_equal Sidekiq::Queue.all.first.size, 2, "Sidekiq queue 2 jobs in queue"

      # 26 hour after.
      assert Sidekiq::Cron::Job.new(@args).test_and_enqueue_for_time! @time + 26 * 60 * 60
      refute Sidekiq::Cron::Job.new(@args).test_and_enqueue_for_time! @time + 26 * 60 * 60

      Sidekiq.redis do |conn|
        assert_equal conn.zcard(Sidekiq::Cron::Job.new(@args).send(:job_enqueued_key)), 1, "Should have one enqueued job - old jobs should be deleted"
      end
      assert_equal Sidekiq::Queue.all.first.size, 3, "Sidekiq queue 3 jobs in queue"
    end
  end

  describe "load" do
    describe "from hash" do
      before do
        @jobs_hash = {
          'name_of_job' => {
            'class' => 'MyClass',
            'cron'  => '1 * * * *',
            'args'  => '(OPTIONAL) [Array or Hash]'
          },
          'My super iber cool job' => {
            'class' => 'SecondClass',
            'cron'  => '*/5 * * * *'
          }
        }
      end

      it "create new jobs and update old one with same settings" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        out = Sidekiq::Cron::Job.load_from_hash @jobs_hash
        assert_equal out.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
      end

      it "duplicate jobs are not loaded" do
        out = Sidekiq::Cron::Job.load_from_hash! @jobs_hash
        assert_equal out.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"

        out_2 = Sidekiq::Cron::Job.load_from_hash! @jobs_hash
        assert_equal out_2.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after loading again"
      end

      it "dynamic jobs are not cleared" do
        args = {
          name: "DynamicJob",
          cron: "* * * * *",
          klass: "CronTestClass",
          source: "dynamic"
        }
        Sidekiq::Cron::Job.create(args)

        out = Sidekiq::Cron::Job.load_from_hash! @jobs_hash
        assert_equal out.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 3, "Should have 3 jobs after load"

        out_2 = Sidekiq::Cron::Job.load_from_hash! @jobs_hash
        assert_equal out_2.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 3, "Should have 3 jobs after loading again"
      end

      it "return errors on loaded jobs" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        # Set something bad to hash.
        @jobs_hash['name_of_job']['cron'] = "bad cron"
        out = Sidekiq::Cron::Job.load_from_hash @jobs_hash
        assert_equal 1, out.size, "should have 1 error"
        assert_includes out['name_of_job'].first, "bad cron"
        assert_includes out['name_of_job'].first, "ArgumentError:"
        assert_equal 1, Sidekiq::Cron::Job.all.size, "Should have only 1 job after load"
      end

      it "create new jobs and then destroy them all" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        out = Sidekiq::Cron::Job.load_from_hash @jobs_hash
        assert_equal out.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
        Sidekiq::Cron::Job.destroy_all!
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs after destroy all"
      end

      it "create new jobs and update old one with same settings with load_from_hash!" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        out = Sidekiq::Cron::Job.load_from_hash! @jobs_hash
        assert_equal out.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
      end
    end

    describe "from array" do
      before do
        @jobs_array = [
          {
            'name'  => 'name_of_job',
            'class' => 'MyClass',
            'cron'  => '1 * * * *',
            'args'  => '(OPTIONAL) [Array or Hash]'
          },
          {
            'name'  => 'Cool Job for Second Class',
            'class' => 'SecondClass',
            'cron'  => '*/5 * * * *'
          }
        ]
      end

      let(:job_names) { ["name_of_job", "Cool Job for Second Class"] }

      it "create new jobs and update old one with same settings" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        out = Sidekiq::Cron::Job.load_from_array @jobs_array
        assert_equal out.size, 0, "should have 0 error"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
      end

      it "duplicate jobs are not loaded" do
        out = Sidekiq::Cron::Job.load_from_array @jobs_array
        assert_equal out.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"

        out_2 = Sidekiq::Cron::Job.load_from_array @jobs_array
        assert_equal out_2.size, 0, "should have no errors"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after loading again"
      end

      describe "with string keys" do
        it "create new jobs and update old one with same settings with load_from_array!" do
          Sidekiq::Cron::Job.expects(:destroy_removed_jobs).with(job_names)

          assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
          out = Sidekiq::Cron::Job.load_from_array! @jobs_array
          assert_equal out.size, 0, "should have 0 error"
          assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
        end
      end

      describe "with symbol keys" do
        it "create new jobs and update old one with same settings with load_from_array!" do
          @jobs_array.map! { |job| job.transform_keys(&:to_sym) }
          Sidekiq::Cron::Job.expects(:destroy_removed_jobs).with(job_names)

          assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
          out = Sidekiq::Cron::Job.load_from_array! @jobs_array
          assert_equal out.size, 0, "should have 0 error"
          assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
        end
      end
    end

    describe "from array with queue_name" do
      before do
        @jobs_array = [
          {
            'name'  => 'name_of_job',
            'class' => 'CronTestClassWithQueue',
            'cron'  => '1 * * * *',
            'args'  => '(OPTIONAL) [Array or Hash]',
            'queue' => 'from_array'
          }
        ]
      end

      it "create new jobs and update old one with same settings" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        out = Sidekiq::Cron::Job.load_from_array @jobs_array
        assert_equal out.size, 0, "should have 0 error"
        assert_equal Sidekiq::Cron::Job.all.size, 1, "Should have 2 jobs after load"

        payload = {
          "retry" => false,
          "backtrace"=>true,
          "queue" => "from_array",
          "class" => "CronTestClassWithQueue",
          "args"  => ['(OPTIONAL) [Array or Hash]']
        }

        assert_equal Sidekiq::Cron::Job.all.first.sidekiq_worker_message, payload
      end
    end
  end

  describe "args=" do
    before do
      @job = Sidekiq::Cron::Job.new(name: "test")
    end

    it "should set args" do
      @job.args = [1, 2, 3]
      assert_equal @job.args, [1, 2, 3]
    end

    it "should set args from string" do
      @job.args = "(1, 2, 3)"
      assert_equal @job.args, ["(1, 2, 3)"]
    end

    it "should set args from hash" do
      @job.args = {a: 1, b: 2}
      assert_equal @job.args, [{a: 1, b: 2}]
    end

    it "should set args from array" do
      @job.args = [{a: 1, b: 2}]
      assert_equal @job.args, [{a: 1, b: 2}]
    end

    it "should set args from GlobalID::Identification" do
      @job.args = Person.new(1)
      assert_equal @job.args, [{"_sc_globalid"=>"gid://app/Person/1"}]
    end

    it "should set args from GlobalID::Identification in Array" do
      @job.args = [Person.new(1)]
      assert_equal @job.args, [{"_sc_globalid"=>"gid://app/Person/1"}]
    end

    it "should set args from GlobalID::Identification in Hash" do
      @job.args = {person: Person.new(1)}
      assert_equal @job.args, [{person: {"_sc_globalid"=>"gid://app/Person/1"}}]
    end
  end
end
