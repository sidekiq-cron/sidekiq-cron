Sidekiq-Cron [![Gem Version](https://badge.fury.io/rb/sidekiq-cron.png)](http://badge.fury.io/rb/sidekiq-cron) [![Build Status](https://travis-ci.org/ondrejbartas/sidekiq-cron.png?branch=master)](https://travis-ci.org/ondrejbartas/sidekiq-cron) [![Coverage Status](https://coveralls.io/repos/ondrejbartas/sidekiq-cron/badge.png?branch=master)](https://coveralls.io/r/ondrejbartas/sidekiq-cron?branch=master)
================================================================================================================================================================================================================================================================================================================================================================================================================================================


Add-on for [Sidekiq](http://sidekiq.org)

Allows you to schedule recurring jobs for sidekiq workers using cron notation _* * * * *_.

Requirements
-----------------

- Redis 2.4 or greater is required.
- Sidekiq 2.13.1 or grater is required.


Installation
------------

    $ gem install sidekiq-cron

or add to your Gemfile

    gem "sidekiq-cron", "~> 0.1.0"


Getting Started
-----------------


If you are not using Rails you need to add `require 'sidekiq-cron'` somewhere after `require 'sidekiq'`.

_Job properties_:

```ruby
{
 'name'  => 'name_of_job', #must be uniq!
 'cron'  => '1 * * * *',
 'klass' => 'MyClass',
 #OPTIONAL
 'queue' => 'name of queue',
 'args'  => '[Array or Hash] of arguments which will be passed to perform method'
}
```

#### Adding Cron job:
```ruby

class HardWorker
  include Sidekiq::Worker
  def perform(name, count)
    # do something
  end
end

Sidekiq::Cron::Job.create( name: 'Hard worker - every 5min', cron: '*/5 * * * *', klass: 'HardWorker')
# => true
```

`create` method will return only true/false if job was saved or not.

```ruby
job = Sidekiq::Cron::Job.new( name: 'Hard worker - every 5min', cron: '*/5 * * * *', klass: 'HardWorker')

if job.valid?
  job.save
else
  puts job.errors
end

#or simple

unless job.save
  puts job.errors #will return array of errors
end
```

Load more jobs from hash:
```ruby

hash = {
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

Sidekiq::Cron::Job.load_from_hash hash
```

Load more jobs from array:
```ruby
array = [
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

Sidekiq::Cron::Job.load_from_array array
```

or from YML (same notation as Resque-scheduler)
```yaml
#config/shedule.yml

my_first_job:
  cron: "*/5 * * * *"
  class: "HardWorker"
  queue: hard_worker

second_job:
  cron: "*/30 * * * *"
  class: "HardWorker"
  queue: hard_worker_long
  args: 
    hard: "stuff"
```

```ruby
#initializers/sidekiq.rb
schedule_file = "config/schedule.yml"

if File.exists?(schedule_file)
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end
```



#### Finding jobs
```ruby
#return array of all jobs
Sidekiq::Cron::Job.all

#return one job by its uniq name - case sensitive
Sidekiq::Cron::Job.find "Job Name"

#return one job by its uniq name - you can use hash with 'name' key
Sidekiq::Cron::Job.find name: "Job Name"

#if job can't be found nil is returned
```

#### Destroy jobs:
```ruby
#destroys all jobs
Sidekiq::Cron::Job.destroy_all!

#destroy job by its name
Sidekiq::Cron::Job.destroy "Job Name"

#destroy founded job
Sidekiq::Cron::Job.find('Job name').destroy
```

#### Work with job:
```ruby
job = Sidekiq::Cron::Job.find('Job name')

#disable cron scheduling
job.disable!

#enable cron scheduling
job.enable!

#get status of job:
job.status
# => enabled/disabled

#enqueue job right now!
job.enque!
```

How to start scheduling?
Just start sidekiq workers by:

    sidekiq

### Web Ui for Cron Jobs

If you are using sidekiq web ui and you would like to add cron josb to web too,
add `require 'sidekiq/cron/web'` after `require 'sidekiq/web'`.
By this you will get:
![Web UI](https://github.com/ondrejbartas/sidekiq-cron/raw/master/examples/web-cron-ui.png)



## Contributing to sidekiq-cron


* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.


## Copyright

Copyright (c) 2013 Ondrej Bartas. See LICENSE.txt for
further details.

