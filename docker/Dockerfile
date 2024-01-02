FROM ruby:3.2

ENV APP_HOME /sidekiq-cron
ENV BUNDLE_GEMFILE=$APP_HOME/Gemfile \
    BUNDLE_JOBS=2 \
    BUNDLE_PATH=/bundle

RUN mkdir -p $APP_HOME/lib/sidekiq/cron

WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
ADD *.gemspec $APP_HOME/
ADD lib/sidekiq/cron/version.rb $APP_HOME/lib/sidekiq/cron/version.rb

RUN gem install bundler \
    && bundle install

ADD . $APP_HOME
