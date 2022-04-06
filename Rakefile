# encoding: utf-8

require 'rubygems'
require 'bundler/setup'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

#TESTING

require 'rake/testtask'
task :default => :test

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/functional/**/*_test.rb', 'test/unit/**/*_test.rb','test/integration/**/*_test.rb']
  t.warning = false
  t.verbose = false
end

namespace :test do
  Rake::TestTask.new(:unit) do |t|
    t.test_files = FileList['test/unit/**/*_test.rb']
    t.warning = false
    t.verbose = false
  end

  Rake::TestTask.new(:functional) do |t|
    t.test_files = FileList['test/functional/**/*_test.rb']
    t.warning = false
    t.verbose = false
  end

  Rake::TestTask.new(:integration) do |t|
    t.test_files = FileList['test/integration/**/*_test.rb']
    t.warning = false
    t.verbose = false
  end
end
