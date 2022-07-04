require 'sidekiq'

module Sidekiq
  module Options
    def self.[](key)
      new_version? ? Sidekiq[key] : Sidekiq.options[key]
    end

    def self.[]=(key, value)
      new_version? ? Sidekiq[key] = value : Sidekiq.options[key] = value
    end

    # sidekiq --version >= 6.5.0
    def self.new_version?
      @new_version ||= Sidekiq.respond_to?(:[])
    end
  end
end
