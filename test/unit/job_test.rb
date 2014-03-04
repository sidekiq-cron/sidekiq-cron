# -*- encoding : utf-8 -*-
require './test/test_helper'

class CronJobTest < Test::Unit::TestCase
  context "Cron Job" do

    setup do 
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

    should "be initialized" do
      job = Sidekiq::Cron::Job.new()
      assert_nil job.last_enqueue_time
      assert job.is_a?(Sidekiq::Cron::Job)
    end

    context "class methods" do
      should "have create method" do
        assert Sidekiq::Cron::Job.respond_to?(:create)
      end

      should "have destroy method" do
        assert Sidekiq::Cron::Job.respond_to?(:destroy)
      end

      should "have count" do
        assert Sidekiq::Cron::Job.respond_to?(:count)
      end

      should "have all" do
        assert Sidekiq::Cron::Job.respond_to?(:all)
      end

      should "have find" do
        assert Sidekiq::Cron::Job.respond_to?(:find)
      end
    end

    context "instance methods" do
      setup do 
        @job = Sidekiq::Cron::Job.new()
      end 
      
      should "have save method" do
        assert @job.respond_to?(:save)
      end
      should "have valid? method" do
        assert @job.respond_to?("valid?".to_sym)
      end
      should "have destroy method" do
        assert @job.respond_to?(:destroy)
      end

      should 'have sort_name - used for sorting enabled disbaled jobs on frontend' do
        job = Sidekiq::Cron::Job.new(name: "TestName")
        assert_equal job.sort_name, "0_testname"
      end
    end

    context "invalid job" do
      
      setup do
        @job = Sidekiq::Cron::Job.new()
      end

      should "allow a class instance for the klass" do
        @job.klass = CronTestClass

        refute @job.valid?
        refute @job.errors.any?{|e| e.include?("klass")}, "Should not have error for klass"
      end

      should "return false on valid? and errors" do
        refute @job.valid?
        assert @job.errors.is_a?(Array)

        assert @job.errors.any?{|e| e.include?("name")}, "Should have error for name"
        assert @job.errors.any?{|e| e.include?("cron")}, "Should have error for cron"
        assert @job.errors.any?{|e| e.include?("klass")}, "Should have error for klass"
      end

      should "return false on valid? with invalid cron" do
        @job.cron = "* s *"
        refute @job.valid?
        assert @job.errors.is_a?(Array)
        assert @job.errors.any?{|e| e.include?("cron")}, "Should have error for cron"
      end

      should "return false on save" do
        refute @job.save
      end
    end

    context "new" do
      setup do 
        @args = {
          name: "Test",
          cron: "* * * * *"
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      should "have all setted attributes" do
        @args.each do |key, value|
          assert_equal @job.send(key), value, "New job should have #{key} with value #{value} but it has: #{@job.send(key)}"
        end
      end

      should "have to_hash method" do
        [:name,:klass,:cron,:args,:message,:status].each do |key|
          assert @job.to_hash.has_key?(key), "to_hash must have key: #{key}"
        end
      end
    end

    context "new with different class inputs" do
      should "be initialized by 'klass' and Class" do
        assert_nothing_raised do
          Sidekiq::Cron::Job.new('klass' => CronTestClass)
        end
      end

      should "be initialized by 'klass' and string Class" do
        assert_nothing_raised do
          Sidekiq::Cron::Job.new('klass' => 'CronTestClass')
        end
      end

      should "be initialized by 'class' and string Class" do
        assert_nothing_raised do
          Sidekiq::Cron::Job.new('class' => 'CronTestClass')
        end
      end

      should "be initialized by 'class' and Class" do
        assert_nothing_raised do
          Sidekiq::Cron::Job.new('class' => CronTestClass)
        end
      end
    end

    context "new should find klass specific settings (queue, retry ...)" do
      should "nothing raise on unknown klass" do
        assert_nothing_raised do
          job = Sidekiq::Cron::Job.new('klass' => 'UnknownCronClass')
          assert_equal job.message, {"class"=>"UnknownCronClass", "args"=>[], "queue"=>"default"}
        end
      end

      should "be initialized with default attributes" do
        assert_nothing_raised do
          job = Sidekiq::Cron::Job.new('klass' => 'CronTestClass')

          assert_equal job.message, {"retry"=>true, "queue"=>"default", "class"=>"CronTestClass", "args"=>[]}
        end
      end

      should "be initialized with class specified attributes" do
        assert_nothing_raised do
          job = Sidekiq::Cron::Job.new('class' => 'CronTestClassWithQueue')
          assert_equal job.message, {"retry"=>false,
                                     "queue"=>:super,
                                     "backtrace"=>true,
                                     "class"=>"CronTestClassWithQueue",
                                     "args"=>[]}
        end
      end

      should "be initialized with 'class' and overwrite queue by settings" do
        assert_nothing_raised do
          job = Sidekiq::Cron::Job.new('class' => CronTestClassWithQueue, queue: 'my_testing_queue')

          assert_equal job.message, {"retry"=>false,
                                     "queue"=>'my_testing_queue',
                                     "backtrace"=>true,
                                     "class"=>"CronTestClassWithQueue",
                                     "args"=>[]}
        end
      end
    end
 
    context "cron test" do
      setup do
        @job = Sidekiq::Cron::Job.new()
      end

      should "return previous minute" do
        @job.cron = "* * * * *"
        time = Time.now
        assert_equal @job.last_time(time).strftime("%Y-%m-%d-%H-%M-%S"), time.strftime("%Y-%m-%d-%H-%M-00")
      end

      should "return previous hour" do
        @job.cron = "1 * * * *"
        time = Time.now
        assert_equal @job.last_time(time).strftime("%Y-%m-%d-%H-%M-%S"), time.strftime("%Y-%m-%d-%H-01-00")
      end

      should "return previous day" do
        @job.cron = "1 2 * * *"
        time = Time.now
        assert_equal @job.last_time(time).strftime("%Y-%m-%d-%H-%M-%S"), time.strftime("%Y-%m-%d-02-01-00")
      end

    end

    context "save" do 
      setup do 
        @args = {
          name: "Test",
          cron: "* * * * *",
          klass: "CronTestClass"
        }
        @job = Sidekiq::Cron::Job.new(@args)
      end

      should "be saved" do
        assert @job.save
      end


      should "be saved and found by name" do
        assert @job.save, "not saved"
        assert Sidekiq::Cron::Job.find("Test").is_a?(Sidekiq::Cron::Job)
      end
    end

    context "nonexisting job" do
      should "not be found" do
        assert Sidekiq::Cron::Job.find("nonexisting").nil?, "should return nil"
      end
    end

    context "disabled/enabled" do
      setup do 
        @args = {
          name: "Test",
          cron: "* * * * *",
          klass: "CronTestClass"
        }
      end

      should "be created and enabled" do
        Sidekiq::Cron::Job.create(@args)
        job = Sidekiq::Cron::Job.find(@args)
        assert_equal job.status, "enabled"
      end

      should "be created and then enabled and disabled" do
        Sidekiq::Cron::Job.create(@args)
        job = Sidekiq::Cron::Job.find(@args)
        assert_equal job.status, "enabled"

        job.enable!
        assert_equal job.status, "enabled"

        job.disable!
        assert_equal job.status, "disabled"
      end

      should "be created with status disabled" do
        Sidekiq::Cron::Job.create(@args.merge(status: "disabled"))
        job = Sidekiq::Cron::Job.find(@args)
        assert_equal job.status, "disabled"
      end

      should "be created with status enabled and disable it afterwards" do
        Sidekiq::Cron::Job.create(@args)
        job = Sidekiq::Cron::Job.find(@args)
        assert_equal job.status, "enabled"
        job.disable!
        assert_equal job.status, "disabled", "directly after call"
        job = Sidekiq::Cron::Job.find(@args)
        assert_equal job.status, "disabled", "after find"
      end

      should "status shouldn't be rewritten after save without status" do
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

      should "last_enqueue_time shouldn't be rewritten after save" do
        #adding last_enqueue_time to initialize is only for test purpose
        last_enqueue_time = '2013-01-01 23:59:59'
        Sidekiq::Cron::Job.create(@args.merge('last_enqueue_time' => last_enqueue_time))
        job = Sidekiq::Cron::Job.find(@args)
        assert_equal job.last_enqueue_time, Time.parse(last_enqueue_time)

        Sidekiq::Cron::Job.create(@args)
        job = Sidekiq::Cron::Job.find(@args)
        assert_equal job.last_enqueue_time, Time.parse(last_enqueue_time), "after second create should have same time"
      end
    end

    context "initialize args" do
      should "from JSON" do
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
      should "from String" do
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
      should "from Array" do
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

    context "create & find methods" do
      setup do 
        @args = {
          name: "Test",
          cron: "* * * * *",
          klass: "CronTestClass"
        }
      end

      should "create first three jobs" do
        assert_equal Sidekiq::Cron::Job.count, 0, "Should have 0 jobs"
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
        Sidekiq::Cron::Job.create(@args.merge(name: "Test3"))
        assert_equal Sidekiq::Cron::Job.count, 3, "Should have 3 jobs"
      end

      should "create first three jobs - 1 has same name" do
        assert_equal Sidekiq::Cron::Job.count, 0, "Should have 0 jobs"
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
        Sidekiq::Cron::Job.create(@args.merge(cron: "1 * * * *"))
        assert_equal Sidekiq::Cron::Job.count, 2, "Should have 2 jobs"
      end

      should "be found by method all" do
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
        Sidekiq::Cron::Job.create(@args.merge(name: "Test3"))
        assert_equal Sidekiq::Cron::Job.all.size, 3, "Should have 3 jobs"
        assert Sidekiq::Cron::Job.all.all?{|j| j.is_a?(Sidekiq::Cron::Job)}, "All returned jobs should be Job class"
      end

      should "be found by method all - defect in set" do
        Sidekiq::Cron::Job.create(@args)
        Sidekiq::Cron::Job.create(@args.merge(name: "Test2"))
        Sidekiq::Cron::Job.create(@args.merge(name: "Test3"))

        Sidekiq.redis do |conn|
          conn.sadd Sidekiq::Cron::Job.jobs_key, "some_other_key"
        end  

        assert_equal Sidekiq::Cron::Job.all.size, 3, "All have to return only valid 3 jobs"
      end

      should "be found by string name" do
        Sidekiq::Cron::Job.create(@args)
        assert Sidekiq::Cron::Job.find("Test")
      end

      should "be found by hash with key name" do
        Sidekiq::Cron::Job.create(@args)
        assert Sidekiq::Cron::Job.find(name: "Test"), "symbol keys keys"

        Sidekiq::Cron::Job.create(@args)
        assert Sidekiq::Cron::Job.find('name' => "Test"), "String keys"
      end

    end

    context "destroy" do 
      setup do 
        @args = {
          name: "Test",
          cron: "* * * * *",
          klass: "CronTestClass"
        }
      end

      should "create and then destroy by hash" do
        Sidekiq::Cron::Job.create(@args)
        assert_equal Sidekiq::Cron::Job.all.size, 1, "Should have 1 job"

        assert Sidekiq::Cron::Job.destroy(@args)
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 job after destroy"
      end

      should "return false on destroying nonexisting" do
        assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs"
        refute Sidekiq::Cron::Job.destroy("nonexisting")
      end

      should "return destroy by string name" do
        Sidekiq::Cron::Job.create(@args)
        assert Sidekiq::Cron::Job.destroy("Test")
      end

      should "return destroy by hash with key name" do
        Sidekiq::Cron::Job.create(@args)
        assert Sidekiq::Cron::Job.destroy(name: "Test"), "symbol keys keys"

        Sidekiq::Cron::Job.create(@args)
        assert Sidekiq::Cron::Job.destroy('name' => "Test"), "String keys"
      end

    end

    context "test of enque" do
      setup do 
        @args = {
          name: "Test",
          cron: "* * * * *",
          klass: "CronTestClass"
        }
        #first time is allways 
        #after next cron time!
        @time = Time.now + 120
      end
      should "be allways false when status is disabled" do
        refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enque? @time
        refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enque? @time - 60
        refute Sidekiq::Cron::Job.new(@args.merge(status: 'disabled')).should_enque? @time - 120
        assert_equal Sidekiq::Queue.all.size, 0, "Sidekiq 0 queues"
      end

      should "be false for same times" do
        assert Sidekiq::Cron::Job.new(@args).should_enque?(@time), "First time - true"
        refute Sidekiq::Cron::Job.new(@args).should_enque? @time
        refute Sidekiq::Cron::Job.new(@args).should_enque? @time
      end

      should "be false for same times but true for next time" do
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

      should "remove old enque times + should be enqeued" do
        job = Sidekiq::Cron::Job.new(@args)
        assert_nil job.last_enqueue_time
        assert job.test_and_enque_for_time!(@time), "should enqueue"
        assert job.last_enqueue_time

        refute Sidekiq::Cron::Job.new(@args).test_and_enque_for_time!(@time), "should not enqueue"
        Sidekiq.redis do |conn|
          assert_equal conn.zcard(Sidekiq::Cron::Job.new(@args).send(:job_enqueued_key)), 2, "Should have two enqueued job (first was in save, second in enque)"
        end
        assert_equal Sidekiq::Queue.all.first.size, 1, "Sidekiq queue 1 job in queue"

        # 20 hours after
        assert Sidekiq::Cron::Job.new(@args).test_and_enque_for_time! @time + 1 * 60 * 60
        refute Sidekiq::Cron::Job.new(@args).test_and_enque_for_time! @time + 1 * 60 * 60

        Sidekiq.redis do |conn|
          assert_equal conn.zcard(Sidekiq::Cron::Job.new(@args).send(:job_enqueued_key)), 3, "Should have two enqueued job + one from start"
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

    context "load" do

      context "from hash" do
        setup do 
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

        should "create new jobs and update old one with same settings" do
          assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
          out = Sidekiq::Cron::Job.load_from_hash @jobs_hash
          assert_equal out.size, 0, "should have no errors"
          assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"          
        end

        should "return errors on loaded jobs" do
          assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
          #set something bag to hash
          @jobs_hash['name_of_job']['cron'] = "bad cron"
          out = Sidekiq::Cron::Job.load_from_hash @jobs_hash
          assert_equal 1, out.size, "should have 1 error"
          assert_equal ({"name_of_job"=>["'cron' -> bad cron: not a valid cronline : 'bad cron'"]}), out
          assert_equal 1, Sidekiq::Cron::Job.all.size, "Should have only 1 job after load"          
        end

        should "create new jobs and then destroy them all" do
          assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
          out = Sidekiq::Cron::Job.load_from_hash @jobs_hash
          assert_equal out.size, 0, "should have no errors"
          assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"          
          Sidekiq::Cron::Job.destroy_all!
          assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs after destroy all"
        end

      end

      context "from array" do
        setup do 
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

        should "create new jobs and update old one with same settings" do
          assert_equal Sidekiq::Cron::Job.all.size, 0, "Should have 0 jobs before load"
          out = Sidekiq::Cron::Job.load_from_array @jobs_array
          assert_equal out.size, 0, "should have 0 error"
          assert_equal Sidekiq::Cron::Job.all.size, 2, "Should have 2 jobs after load"          
        end
      end
    end
  end
end
