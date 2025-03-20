module Sidekiq
  module Cron
    module WebExtension
      module Helpers
        def cron_route_params(key)
          if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("8.0.0")
            route_params(key)
          else
            route_params[key]
          end
        end

        # This method constructs the URL for the cron jobs page within the specified namespace.
        def namespace_redirect_path
          "#{root_path}cron/namespaces/#{cron_route_params(:namespace)}"
        end

        def redirect_to_previous_or_default
          if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("8.0.0")
            redirect url_params('redirect') || namespace_redirect_path
          else
            redirect params["redirect"] || namespace_redirect_path
          end
        end

        def render_erb(view)
          path = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("8.0.0") ? "views" : "views/legacy"
          views_path = File.join(File.expand_path("..", __FILE__), path)
          erb(File.read(File.join(views_path, "#{view}.erb")))
        end
      end

      def self.registered(app)
        locales = if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("8.0.0")
                    Sidekiq::Web.configure.locales
                  else
                    app.settings.locales
                  end

        locales << File.join(File.expand_path("..", __FILE__), "locales")

        app.helpers(Helpers)

        # Index page.
        app.get '/cron' do
          @current_namespace = 'default'
          @cron_jobs = Sidekiq::Cron::Job.all(@current_namespace)

          render_erb(:cron)
        end

        # Detail page for a specific namespace.
        app.get '/cron/namespaces/:name' do
          @current_namespace = cron_route_params(:name)
          @cron_jobs = Sidekiq::Cron::Job.all(@current_namespace)

          render_erb(:cron)
        end

        # Display job detail + jid history.
        app.get '/cron/namespaces/:namespace/jobs/:name' do
          @current_namespace = cron_route_params(:namespace)
          @job = Sidekiq::Cron::Job.find(cron_route_params(:name), @current_namespace)

          if @job
            render_erb(:cron_show)
          else
            redirect namespace_redirect_path
          end
        end

        # Enqueue all cron jobs.
        app.post '/cron/namespaces/:namespace/all/enqueue' do
          Sidekiq::Cron::Job.all(cron_route_params(:namespace)).each(&:enqueue!)

          redirect_to_previous_or_default
        end

        # Enqueue cron job.
        app.post '/cron/namespaces/:namespace/jobs/:name/enqueue' do
          if job = Sidekiq::Cron::Job.find(cron_route_params(:name), cron_route_params(:namespace))
            job.enqueue!
          end

          redirect_to_previous_or_default
        end

        # Delete all schedules.
        app.post '/cron/namespaces/:namespace/all/delete' do
          Sidekiq::Cron::Job.all(cron_route_params(:namespace)).each(&:destroy)

          redirect_to_previous_or_default
        end

        # Delete schedule.
        app.post '/cron/namespaces/:namespace/jobs/:name/delete' do
          if job = Sidekiq::Cron::Job.find(cron_route_params(:name), cron_route_params(:namespace))
            job.destroy
          end

          redirect_to_previous_or_default
        end

        # Enable all jobs.
        app.post '/cron/namespaces/:namespace/all/enable' do
          Sidekiq::Cron::Job.all(cron_route_params(:namespace)).each(&:enable!)

          redirect_to_previous_or_default
        end

        # Enable job.
        app.post '/cron/namespaces/:namespace/jobs/:name/enable' do
          if job = Sidekiq::Cron::Job.find(cron_route_params(:name), cron_route_params(:namespace))
            job.enable!
          end

          redirect_to_previous_or_default
        end

        # Disable all jobs.
        app.post '/cron/namespaces/:namespace/all/disable' do
          Sidekiq::Cron::Job.all(cron_route_params(:namespace)).each(&:disable!)

          redirect_to_previous_or_default
        end

        # Disable job.
        app.post '/cron/namespaces/:namespace/jobs/:name/disable' do
          if job = Sidekiq::Cron::Job.find(cron_route_params(:name), cron_route_params(:namespace))
            job.disable!
          end

          redirect_to_previous_or_default
        end
      end
    end
  end
end
