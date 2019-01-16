# -*- encoding : utf-8 -*-
require './test/test_helper'

describe "Cron Job" do
  before do
    #clear all previous saved data from redis
    Sidekiq.redis do |conn|
      conn.keys("cron_job*").each do |key|
        conn.del(key)
      end
    end

    #clear all queues
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
      assert Sidekiq::Cron::Job.respond_to?(:create)
    end

    it "have destroy method" do
      assert Sidekiq::Cron::Job.respond_to?(:destroy)
    end

    it "have count" do
      assert Sidekiq::Cron::Job.respond_to?(:count)
    end

    it "have all" do
      assert Sidekiq::Cron::Job.respond_to?(:all)
    end

    it "have find" do
      assert Sidekiq::Cron::Job.respond_to?(:find)
    end
  end

  describe "instance methods" do
    before do
      @job = Sidekiq::Cron::Job.new()
    end

    it "have save method" do
      assert @job.respond_to?(:save)
    end

    it "have valid? method" do
      assert @job.respond_to?("valid?".to_sym)
    end

    it "have destroy method" do
      assert @job.respond_to?(:destroy)
    end

    it "have enabled? method" do
      assert @job.respond_to?(:enabled?)
    end

    it "have disabled? method" do
      assert @job.respond_to?(:disabled?)
    end

    it 'have sort_name - used for sorting enabled disbaled jobs on frontend' do
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

    it "have all setted attributes" do
      @args.each do |key, value|
        assert_equal @job.send(key), value, "New job should have #{key} with value #{value} but it has: #{@job.send(key)}"
      end
    end

    it "have to_hash method" do
      [:name,:klass,:cron,:description,:args,:message,:status].each do |key|
        assert @job.to_hash.has_key?(key), "to_hash must have key: #{key}"
      end
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
      assert_equal '2015-01-02T02:04:00Z', @job.formated_last_time(@time)
    end

    it 'returns formated_enqueue_time' do
      assert_equal '1420164240.0', @job.formated_enqueue_time(@time)
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

    it "be initialized with 'class' and date_as_argument" do
      job = Sidekiq::Cron::Job.new('class' => 'CronTestClassWithQueue', "date_as_argument" => true)

      job_message = job.message
      job_args    = job_message.delete("args")
      assert_equal job_message, {"retry"=>false,
                                 "queue"=>:super,
                                 "backtrace"=>true,
                                 "class"=>"CronTestClassWithQueue"}
      assert job_args[-1].is_a?(Float)
      assert job_args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
    end

    it "be initialized with 'class', 2 arguments and date_as_argument" do
      job = Sidekiq::Cron::Job.new('class' => 'CronTestClassWithQueue', "date_as_argument" => true, "args"=> ["arg1", :arg2])

      job_message = job.message
      job_args    = job_message.delete("args")
      assert_equal job_message, {"retry"=>false,
                                 "queue"=>:super,
                                 "backtrace"=>true,
                                 "class"=>"CronTestClassWithQueue"}
      assert job_args[-1].is_a?(Float)
      assert job_args[-1].between?(Time.now.to_f - 1, Time.now.to_f)
      assert_equal job_args[0..-2], ["arg1", :arg2]
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

  describe '#active_job_message' do
    before do
      SecureRandom.stubs(:uuid).returns('XYZ')
      ActiveJob::Base.queue_name_prefix = ''

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
  end

  describe '#active_job_message with queue_name_prefix' do
    before do
      SecureRandom.stubs(:uuid).returns('XYZ')
      ActiveJob::Base.queue_name_prefix = "prefix"

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

  describe '#enque!' do
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
        @job.enque!
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
        @job.enque!
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
        @job.enque!
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
        @job.enque!
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
        @job.enque!
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
        @job.enque!
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
        @job.enque!
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
        @job.enque!
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
        @job.enque!
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
      assert Sidekiq::Cron::Job.find("nonexisting").nil?, "should return nil"
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
      #adding last_enqueue_time to initialize is only for test purpose
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
        conn.sadd Sidekiq::Cron::Job.jobs_key, "some_other_key"
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

  describe "destroy_removed_jobs" do
    before do
      args1 = {
        name: "WillBeErasedJob",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
      Sidekiq::Cron::Job.create(args1)

      args2 = {
        name: "ContinueRemainingJob",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
      Sidekiq::Cron::Job.create(args2)
    end

    it "be destroied removed job that not exists in args" do
      assert_equal Sidekiq::Cron::Job.destroy_removed_jobs(["ContinueRemainingJob"]), ["WillBeErasedJob"], "Should be destroyed WillBeErasedJob"
    end
  end

  describe "test of enque" do
    before do
      @args = {
        name: "Test",
        cron: "* * * * *",
        klass: "CronTestClass"
      }
      #first time is allways
      #after next cron time!
      @time = Time.now.utc + 120
    end
    it "be allways false when status is disabled" do
      refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enque? @time
      refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enque? @time - 60
      refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enque? @time - 120
      assert_equal Sidekiq::Queue.all.size, 0, "Sidekiq 0 queues"
    end

    it "be false for same times" do
      assert Sidekiq::Cron::Job.new(@args).should_enque?(@time), "First time - true"
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time
    end

    it "be false for same times but true for next time" do
      assert Sidekiq::Cron::Job.new(@args).should_enque?(@time), "First time - true"
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time
      assert Sidekiq::Cron::Job.new(@args).should_enque? @time + 135
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time + 135
      assert Sidekiq::Cron::Job.new(@args).should_enque? @time + 235
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time + 235

      #just for check
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time + 135
      refute Sidekiq::Cron::Job.new(@args).should_enque? @time + 235
    end

    it "should not enqueue jobs that are past" do
      assert Sidekiq::Cron::Job.new(@args.merge(cron: "*/1 * * * *")).should_enque? @time
      refute Sidekiq::Cron::Job.new(@args.merge(cron: "0 1,13 * * *")).should_enque? @time
    end

    it 'doesnt skip enqueuing if job is resaved near next enqueue time' do
      job = Sidekiq::Cron::Job.new(@args)
      assert job.test_and_enque_for_time!(@time), "should enqueue"

      future_now = @time + 1 * 60 * 60
      Time.stubs(:now).returns(future_now) # save uses Time.now.utc
      job.save
      assert Sidekiq::Cron::Job.new(@args).test_and_enque_for_time!(future_now + 30), "should enqueue"
    end

    it "remove old enque times + should be enqeued" do
      job = Sidekiq::Cron::Job.new(@args)
      assert_nil job.last_enqueue_time
      assert job.test_and_enque_for_time!(@time), "should enqueue"
      assert job.last_enqueue_time

      refute Sidekiq::Cron::Job.new(@args).test_and_enque_for_time!(@time), "should not enqueue"
      Sidekiq.redis do |conn|
        assert_equal conn.zcard(Sidekiq::Cron::Job.new(@args).send(:job_enqueued_key)), 1, "Should have one enqueued job"
      end
      assert_equal Sidekiq::Queue.all.first.size, 1, "Sidekiq queue 1 job in queue"

      # 20 hours after
      assert Sidekiq::Cron::Job.new(@args).test_and_enque_for_time! @time + 1 * 60 * 60
      refute Sidekiq::Cron::Job.new(@args).test_and_enque_for_time! @time + 1 * 60 * 60

      Sidekiq.redis do |conn|
        assert_equal conn.zcard(Sidekiq::Cron::Job.new(@args).send(:job_enqueued_key)), 2, "Should have two enqueued job"
      end
      assert_equal Sidekiq::Queue.all.first.size, 2, "Sidekiq queue 2 jobs in queue"

      # 26 hour after
      assert Sidekiq::Cron::Job.new(@args).test_and_enque_for_time! @time + 26 * 60 * 60
      refute Sidekiq::Cron::Job.new(@args).test_and_enque_for_time! @time + 26 * 60 * 60

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

      it "return errors on loaded jobs" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        #set something bag to hash
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

      it "create new jobs and update old one with same settings" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        out = Sidekiq::Cron::Job.load_from_array @jobs_array
        assert_equal out.size, 0, "should have 0 error"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
      end

      it "create new jobs and update old one with same settings with load_from_array" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
        out = Sidekiq::Cron::Job.load_from_array! @jobs_array
        assert_equal out.size, 0, "should have 0 error"
        assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"
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
end
