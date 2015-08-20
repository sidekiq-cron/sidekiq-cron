require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/actor'
require 'rufus-scheduler'

module Sidekiq
  module Cron

    class Job
      include Util
      extend Util

      #how long we would like to store informations about previous enqueues
      REMEMBER_THRESHOLD = 24 * 60 * 60

      #crucial part of whole enquing job
      def should_enque? time
        enqueue = false
        enqueue = Sidekiq.redis do |conn|
          status == "enabled" && not_enqueued_after?(time) && conn.zadd(job_enqueued_key, time.to_f.to_s, formated_last_time(time))
        end
        enqueue
      end

      # remove previous informations about run times
      # this will clear redis and make sure that redis will
      # not overflow with memory
      def remove_previous_enques time
        Sidekiq.redis do |conn|
          conn.zremrangebyscore(job_enqueued_key, 0, "(#{(time.to_f - REMEMBER_THRESHOLD).to_s}")
        end
      end

      #test if job should be enqued If yes add it to queue
      def test_and_enque_for_time! time
        #should this job be enqued?
        if should_enque?(time)
          enque!

          remove_previous_enques(time)
        end
      end

      #enque cron job to queue
      def enque! time = Time.now
        @last_enqueue_time = time

        if defined?(ActiveJob::Base) && @klass.to_s.constantize < ActiveJob::Base
          Sidekiq::Client.push(active_job_message)
        else
          Sidekiq::Client.push(sidekiq_worker_message)
        end

        save
        logger.debug { "enqueued #{@name}: #{@message}" }
      end

      # siodekiq worker message
      def sidekiq_worker_message
        @message.is_a?(String) ? Sidekiq.load_json(@message) : @message
      end

      # active job has different structure how it is loading data from sidekiq
      # queue, it createaswrapper arround job
      def active_job_message
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'queue' => @queue,
          'args'  => [{
            'job_class'  => @klass,
            'job_id'     => SecureRandom.uuid,
            'queue_name' => @queue,
            'arguments'  => @args
          }]
        }
      end

      # load cron jobs from Hash
      # input structure should look like:
      # {
      #   'name_of_job' => {
      #     'class' => 'MyClass',
      #     'cron'  => '1 * * * *',
      #     'args'  => '(OPTIONAL) [Array or Hash]'
      #   },
      #   'My super iber cool job' => {
      #     'class' => 'SecondClass',
      #     'cron'  => '*/5 * * * *'
      #   }
      # }
      #
      def self.load_from_hash hash
        array = hash.inject([]) do |out,(key, job)|
          job['name'] = key
          out << job
        end
        load_from_array array
      end

      # like to {#load_from_hash}
      # If exists old jobs in redis but removed from args, destroy old jobs
      def self.load_from_hash! hash
        destroy_removed_jobs(hash.keys)
        load_from_hash(hash)
      end

      # load cron jobs from Array
      # input structure should look like:
      # [
      #   {
      #     'name'  => 'name_of_job',
      #     'class' => 'MyClass',
      #     'cron'  => '1 * * * *',
      #     'args'  => '(OPTIONAL) [Array or Hash]'
      #   },
      #   {
      #     'name'  => 'Cool Job for Second Class',
      #     'class' => 'SecondClass',
      #     'cron'  => '*/5 * * * *'
      #   }
      # ]
      #
      def self.load_from_array array
        errors = {}
        array.each do |job_data|
          job = new(job_data)
          errors[job.name] = job.errors unless job.save
        end
        errors
      end

      # like to {#load_from_array}
      # If exists old jobs in redis but removed from args, destroy old jobs
      def self.load_from_array! array
        job_names = array.map { |job| job["name"] }
        destroy_removed_jobs(job_names)
        load_from_array(array)
      end

      # get all cron jobs
      def self.all
        out = []
        Sidekiq.redis do |conn|
          out = conn.smembers(jobs_key).collect do |key|
            if conn.exists key
              Job.new conn.hgetall(key)
            else
              nil
            end
          end
        end
        out.select{|j| !j.nil? }
      end

      def self.count
        out = 0
        Sidekiq.redis do |conn|
          out = conn.scard(jobs_key)
        end
        out
      end

      def self.find name
        #if name is hash try to get name from it
        name = name[:name] || name['name'] if name.is_a?(Hash)

        output = nil
        Sidekiq.redis do |conn|
          if exists? name
            output = Job.new conn.hgetall( redis_key(name) )
          end
        end
        output
      end

      # create new instance of cron job
      def self.create hash
        new(hash).save
      end

      #destroy job by name
      def self.destroy name
        #if name is hash try to get name from it
        name = name[:name] || name['name'] if name.is_a?(Hash)

        if job = find(name)
          job.destroy
        else
          false
        end
      end

      attr_accessor :name, :cron, :klass, :args, :message
      attr_reader   :last_enqueue_time

      def initialize input_args = {}
        args = input_args.stringify_keys

        @name = args["name"]
        @cron = args["cron"]

        #get class from klass or class
        @klass = args["klass"] || args["class"]

        #set status of job
        @status = args['status'] || status_from_redis

        #set last enqueue time - from args or from existing job
        if args['last_enqueue_time'] && !args['last_enqueue_time'].empty?
          @last_enqueue_time = Time.parse(args['last_enqueue_time'])
        else
          @last_enqueue_time = last_enqueue_time_from_redis
        end

        #get right arguments for job
        @args = args["args"].nil? ? [] : parse_args( args["args"] )

        if args["message"]
          @message = args["message"]
          message_data = Sidekiq.load_json(@message) || {}
          @queue = message_data['queue'] || default
        elsif @klass
          message_data = {
            "class" => @klass.to_s,
            "args"  => @args,
          }

          #get right data for message
          #only if message wasn't specified before
          message_data = case @klass
            when Class
              @klass.get_sidekiq_options.merge(message_data)
            when String
              begin
                @klass.constantize.get_sidekiq_options.merge(message_data)
              rescue
                #Unknown class
                message_data.merge("queue"=>"default")
              end

          end

          #override queue if setted in config
          #only if message is hash - can be string (dumped JSON)
          if args['queue']
            @queue = message_data['queue'] = args['queue']
          else
            @queue = message_data['queue'] || default
          end

          #dump message as json
          @message = message_data
        end

      end

      def status
        @status
      end

      def disable!
        @status = "disabled"
        save
      end

      def enable!
        @status = "enabled"
        save
      end

      def status_from_redis
        out = "enabled"
        if exists?
          Sidekiq.redis do |conn|
            out = conn.hget redis_key, "status"
          end
        end
        out
      end

      def last_enqueue_time_from_redis
        out = nil
        if exists?
          Sidekiq.redis do |conn|
            out = Time.parse(conn.hget(redis_key, "last_enqueue_time")) rescue nil
          end
        end
        out
      end

      #export job data to hash
      def to_hash
        {
          name: @name,
          klass: @klass,
          cron: @cron,
          args: @args.is_a?(String) ? @args : Sidekiq.dump_json(@args || []),
          message: @message.is_a?(String) ? @message : Sidekiq.dump_json(@message || {}),
          status: @status,
          last_enqueue_time: @last_enqueue_time,
        }
      end

      def errors
        @errors ||= []
      end

      def valid?
        #clear previos errors
        @errors = []

        errors << "'name' must be set" if @name.nil? || @name.size == 0
        if @cron.nil? || @cron.size == 0
          errors << "'cron' must be set"
        else
          begin
            cron = Rufus::Scheduler::CronLine.new(@cron)
            cron.next_time(Time.now)
          rescue Exception => e
            #fix for different versions of cron-parser
            if e.message == "Bad Vixie-style specification bad"
              errors << "'cron' -> #{@cron}: not a valid cronline"
            else
              errors << "'cron' -> #{@cron}: #{e.message}"
            end
          end
        end

        errors << "'klass' (or class) must be set" unless klass_valid

        !errors.any?
      end

      def klass_valid
        case @klass
          when Class
            true
          when String
            @klass.size > 0
          else
        end
      end

      # add job to cron jobs
      # input:
      #   name: (string) - name of job
      #   cron: (string: '* * * * *' - cron specification when to run job
      #   class: (string|class) - which class to perform
      # optional input:
      #   queue: (string) - which queue to use for enquing (will override class queue)
      #   args: (array|hash|nil) - arguments for permorm method

      def save
        #if job is invalid return false
        return false unless valid?

        Sidekiq.redis do |conn|

          #add to set of all jobs
          conn.sadd self.class.jobs_key, redis_key

          #add informations for this job!
          conn.hmset redis_key, *hash_to_redis(to_hash)

          #add information about last time! - don't enque right after scheduler poller starts!
          time = Time.now
          conn.zadd(job_enqueued_key, time.to_f.to_s, formated_last_time(time).to_s)
        end
        logger.info { "Cron Jobs - add job with name: #{@name}" }
      end

      # remove job from cron jobs by name
      # input:
      #   first arg: name (string) - name of job (must be same - case sensitive)
      def destroy
        Sidekiq.redis do |conn|
          #delete from set
          conn.srem self.class.jobs_key, redis_key

          #delete runned timestamps
          conn.del job_enqueued_key

          #delete main job
          conn.del redis_key
        end
        logger.info { "Cron Jobs - deleted job with name: #{@name}" }
      end

      # remove all job from cron
      def self.destroy_all!
        all.each do |job|
          job.destroy
        end
        logger.info { "Cron Jobs - deleted all jobs" }
      end

      # remove "removed jobs" between current jobs and new jobs
      def self.destroy_removed_jobs new_job_names
        current_job_names = Sidekiq::Cron::Job.all.map(&:name)
        removed_job_names = current_job_names - new_job_names
        removed_job_names.each { |j| Sidekiq::Cron::Job.destroy(j) }
        removed_job_names
      end

      # Parse cron specification '* * * * *' and returns
      # time when last run should be performed
      def last_time now = Time.now
        Rufus::Scheduler::CronLine.new(@cron).previous_time(now)
      end

      def formated_last_time now = Time.now
        last_time(now).getutc
      end

      def self.exists? name
        out = false
        Sidekiq.redis do |conn|
          out = conn.exists redis_key name
        end
        out
      end

      def exists?
        self.class.exists? @name
      end

      def sort_name
        "#{status == "enabled" ? 0 : 1}_#{name}".downcase
      end

      private

      def not_enqueued_after?(time)
        @last_enqueue_time.nil? || @last_enqueue_time < last_time(time)
      end

      # Try parsing inbound args into an array.
      # args from Redis will be encoded JSON;
      # try to load JSON, then failover
      # to string array.
      def parse_args(args)
        case args
        when String
          begin
            Sidekiq.load_json(args)
          rescue JSON::ParserError
            [*args]   # cast to string array
          end
        when Hash
          [args]      # just put hash into array
        when Array
          args        # do nothing, already array
        else
          [*args]     # cast to string array
        end
      end

      # Redis key for set of all cron jobs
      def self.jobs_key
        "cron_jobs"
      end

      # Redis key for storing one cron job
      def self.redis_key name
        "cron_job:#{name}"
      end

      # Redis key for storing one cron job
      def redis_key
        self.class.redis_key @name
      end

      # Redis key for storing one cron job run times
      # (when poller added job to queue)
      def self.job_enqueued_key name
        "cron_job:#{name}:enqueued"
      end

      # Redis key for storing one cron job run times
      # (when poller added job to queue)
      def job_enqueued_key
        self.class.job_enqueued_key @name
      end

      # Give Hash
      # returns array for using it for redis.hmset
      def hash_to_redis hash
        hash.inject([]){ |arr,kv| arr + [kv[0], kv[1]] }
      end

    end
  end
end
