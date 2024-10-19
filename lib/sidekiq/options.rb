# Module to access Sidekiq config
module Sidekiq
  module Options
    def self.[](key)
      self.config[key]
    end

    def self.[]=(key, value)
      self.config[key] = value
    end

    def self.config
      options_field ? Sidekiq.public_send(options_field) : Sidekiq
    end

    def self.options_field
      return @options_field unless @options_field.nil?

      sidekiq_version = Gem::Version.new(Sidekiq::VERSION)
      @options_field = if sidekiq_version >= Gem::Version.new('7.0')
        :default_configuration
      else
        false
      end
    end
  end
end
