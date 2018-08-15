v 1.0.4
-------

- fix problem with upgrading to 1.0.x - parsing last enqued time didn't count with old time format stored in redis

v 1.0.0
-------

- use [fugit](https://github.com/floraison/fugit) instead of [rufus-scheduler](https://github.com/jmettraux/rufus-scheduler) - API of cron didn't change (rufus scheduler is using fugit)
- better working with Timezones
- translations for JA, zh-CN
- cron without timezone are considered as UTC, to add Timezone to cron use format `* * * * * Europe/Berlin`
- be aware that this release can change when your jobs are enqueued (for me it didn't change but it is in one project, in other it can shift by different timezone setup)

v 0.6.0
-------

- set poller to check jobs every 30s by default (possible to override by `Sidekiq.options[:poll_interval] = 10`)
- add group actions (enqueue, enable, disable, delete) all in web view
- fix poller to enqueu all jobs in poll start time
- add performance test for enqueue of jobs (10 000 jobs in less than 19s)
- fix problem with default queue
- remove redis-namespace from dependencies
- update ruby versions in travis

v 0.5.0
-------
- add docker support
- all crons are now evaluated in UTC
- fix rufus scheduler & timezones problems
- add support for sidekiq 4.2.1
- fix readme
- add Russian locale
- user Rack.env in tests
- faster enque of jobs
- permit to use ActiveJob::Base.queue_name_delimiter
- fix problem with multiple times enque #84
- fix problem with enque of unknown class

v 0.4.0
-------

- enable to work with sidekiq >= 4.0.0
- fix readme

v 0.3.1
-------

- add CSRF tags to forms so it will work with sidekiq >= 3.4.2
- remove tilt dependency

v 0.3.0
-------

- suport for Active Job
- sidekiq cron web ui needs to be loaded by: require 'sidekiq/cron/web'
- add load_from_hash! and load_from_array! which cleanup jobs before adding new ones

v 0.1.1
-------

- add Web fontend with enabled/disable job, unqueue now, delete job
- add cron poller - enqueu cro jobs
- add cron job - save all needed data to redis
