module Sidekiq
  module Cron
    module WebExtension
      def self.registered(app)
        app.settings.locales << File.join(File.expand_path("..", __FILE__), "locales")

        # Index page of cron jobs.
        app.get '/cron' do
          view_path = File.join(File.expand_path("..", __FILE__), "views")

          @current_namespace = 'default'

          @namespaces = Sidekiq::Cron::Namespace.all_with_count

          # Not passing namespace takes all the jobs from the default one.
          @cron_jobs = Sidekiq::Cron::Job.all

          render(:erb, File.read(File.join(view_path, "cron.erb")))
        end

        app.get '/cron/namespaces/:name' do
          view_path = File.join(File.expand_path("..", __FILE__), "views")

          @current_namespace = route_params[:name]

          @namespaces = Sidekiq::Cron::Namespace.all_with_count

          @cron_jobs = Sidekiq::Cron::Job.all(@current_namespace)

          render(:erb, File.read(File.join(view_path, "cron.erb")))
        end

        # Display job detail + jid history.
        app.get '/cron/namespaces/:namespace/jobs/:name' do
          view_path = File.join(File.expand_path("..", __FILE__), "views")

          @current_namespace = route_params[:namespace]
          @job_name = route_params[:name]

          @namespaces = Sidekiq::Cron::Namespace.all_with_count

          @job = Sidekiq::Cron::Job.find(@job_name, @current_namespace)

          if @job
            render(:erb, File.read(File.join(view_path, "cron_show.erb")))
          else
            redirect "#{root_path}cron/namespaces/#{route_params[:namespace]}"
          end
        end

        # Enque all cron jobs.
        app.post '/cron/namespaces/:namespace/all/enque' do
          Sidekiq::Cron::Job.all(route_params[:namespace]).each(&:enque!)
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end

        # Enqueue cron job.
        app.post '/cron/namespaces/:namespace/jobs/:name/enque' do
          if (job = Sidekiq::Cron::Job.find(route_params[:name], route_params[:namespace]))
            job.enque!
          end
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end

        # Delete all schedules.
        app.post '/cron/namespaces/:namespace/all/delete' do
          Sidekiq::Cron::Job.all(route_params[:namespace]).each(&:destroy)
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end

        # Delete schedule.
        app.post '/cron/namespaces/:namespace/jobs/:name/delete' do
          if (job = Sidekiq::Cron::Job.find(route_params[:name], route_params[:namespace]))
            job.destroy
          end
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end

        # Enable all jobs.
        app.post '/cron/namespaces/:namespace/all/enable' do
          Sidekiq::Cron::Job.all(route_params[:namespace]).each(&:enable!)
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end

        # Enable job.
        app.post '/cron/namespaces/:namespace/jobs/:name/enable' do
          if (job = Sidekiq::Cron::Job.find(route_params[:name], route_params[:namespace]))
            job.enable!
          end
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end

        # Disable all jobs.
        app.post '/cron/namespaces/:namespace/all/disable' do
          Sidekiq::Cron::Job.all(route_params[:namespace]).each(&:disable!)
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end

        # Disable job.
        app.post '/cron/namespaces/:namespace/jobs/:name/disable' do
          if (job = Sidekiq::Cron::Job.find(route_params[:name], route_params[:namespace]))
            job.disable!
          end
          redirect params['redirect'] || "#{root_path}cron/namespaces/#{route_params[:namespace]}"
        end
      end
    end
  end
end
