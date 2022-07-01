require 'sidekiq'

module Sidekiq
  module Options
    def self.[](key)
      Sidekiq.respond_to?(:[]) ? Sidekiq[key] : Sidekiq.options[key]
    end
  end
end
