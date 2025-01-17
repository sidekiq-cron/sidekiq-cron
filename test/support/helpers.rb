def capture_logging(level:)
  original_logger = Sidekiq.logger

  logdev = StringIO.new
  logger = ::Logger.new(logdev)
  logger.level = level

  Sidekiq.configure_server { |c| c.logger = logger }

  yield

  logdev.string
ensure
  Sidekiq.configure_server do |c|
    c.logger = original_logger
  end
end
