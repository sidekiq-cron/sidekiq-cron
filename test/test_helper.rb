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

require "minitest/autorun"
require 'shoulda-context'
require 'turn'

#SIDEKIQ Require - need to have sidekiq running!
require 'sidekiq'
require 'sidekiq/util'
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

class Test::Unit::TestCase
end
