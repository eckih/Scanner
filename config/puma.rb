# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
#
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
if ENV.fetch("RAILS_ENV", "development") == "production"
  workers ENV.fetch("WEB_CONCURRENCY") { 2 }
  
  # Use the `preload_app!` method when specifying a `workers` number.
  # This directive tells Puma to first boot the application and load code
  # before forking the application. This takes advantage of Copy On Write
  # process behavior so workers use less memory.
  #
  preload_app!
  
  # Allow puma to be restarted by `rails restart` command.
  plugin :tmp_restart
  
  # Worker timeout
  worker_timeout 60
  
  # Worker boot timeout
  worker_boot_timeout 60
  
  # Worker shutdown timeout
  worker_shutdown_timeout 30
  
  # Bind to all interfaces in production
  bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"
  
  # Redirect STDOUT/STDERR to files in production
  if ENV["RAILS_LOG_TO_STDOUT"].blank?
    stdout_redirect "log/puma_access.log", "log/puma_error.log", true
  end
  
  # Set up socket activation for systemd
  if ENV["LISTEN_PID"]
    require 'sd_notify'
    before_fork do
      SdNotify.ready
    end
  end
  
  # Graceful shutdown
  on_worker_boot do
    # Worker specific setup for Rails 4.1+
    # See: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end
  
  on_worker_shutdown do
    # Worker specific cleanup
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end
  
  # Memory and CPU monitoring
  before_fork do
    # Close database connections
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end
  
  # Restart workers if they consume too much memory
  if ENV["PUMA_WORKER_MAX_MEMORY"]
    require 'get_process_mem'
    
    on_worker_boot do
      @worker_memory_monitor = Thread.new do
        loop do
          memory_mb = GetProcessMem.new.mb
          if memory_mb > ENV["PUMA_WORKER_MAX_MEMORY"].to_i
            Process.kill("TERM", Process.pid)
          end
          sleep 30
        end
      end
    end
    
    on_worker_shutdown do
      @worker_memory_monitor&.kill
    end
  end
else
  # Development/test configuration
  workers 0
end

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart 