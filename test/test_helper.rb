require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'simplecov'
SimpleCov.start do
  add_filter "/test/"

  add_group 'SidekiqCron', 'lib/'
end
require 'coveralls'
Coveralls.wear!

require "minitest/autorun"
require 'shoulda-context'
require "rack/test"
require "mocha/setup"

#SIDEKIQ Require - need to have sidekiq running!
require 'celluloid/autostart'
require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/web'

Sidekiq.logger.level = Logger::ERROR

require 'sidekiq/redis_connection'
redis_url = ENV['REDIS_URL'] || 'redis://localhost/15'
REDIS = Sidekiq::RedisConnection.create(:url => redis_url, :namespace => 'testy')

Sidekiq.configure_client do |config|
  config.redis = { :url => redis_url, :namespace => 'testy' }
end


$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'sidekiq-cron'
require 'sidekiq/cron/web'

class CronTestClass
  include Sidekiq::Worker

  def perform args = {}
    puts "super croned job #{args}"
  end
end

class CronTestClassWithQueue
  include Sidekiq::Worker
  sidekiq_options :queue => :super, :retry => false, :backtrace => true

  def perform args = {}
    puts "super croned job #{args}"
  end
end
