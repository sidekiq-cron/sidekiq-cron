require "sidekiq"

module SidekiqOptions
  def self.[](key)
    Sidekiq.respond_to?(:[]) ? Sidekiq[key] : Sidekiq.options[key]
  end
end
