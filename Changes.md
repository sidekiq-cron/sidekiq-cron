v 0.3.1
-------

- add CSRF tags to forms so it will work with sidekiq >= 3.4.2
- remove titl dependency

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
