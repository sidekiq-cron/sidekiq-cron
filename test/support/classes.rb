class CronTestClass
  include Sidekiq::Worker
  sidekiq_options retry: true

  def perform args = {}
    puts "super croned job #{args}"
  end
end

class CronTestClassWithQueue
  include Sidekiq::Worker
  sidekiq_options queue: :super, retry: false, backtrace: true

  def perform args = {}
    puts "super croned job #{args}"
  end
end

class ActiveJobCronTestClass < ::ActiveJob::Base
  def perform(*)
    nil
  end
end

class ActiveJobCronTestClassWithQueue < ::ActiveJob::Base
  queue_as :super

  def perform(*)
    nil
  end
end

class Person
  include GlobalID::Identification

  attr_reader :id

  def self.find(id)
    new(id)
  end

  def initialize(id)
    @id = id
  end

  def to_global_id(_options = {})
    super app: "app"
  end

  def ==(other_person)
    other_person.is_a?(Person) && id.to_s == other_person.id.to_s
  end
end
