module Sidekiq
  module Cron
    module WebExtension

      def self.registered(app)

        app.settings.locales << File.join(File.expand_path("..", __FILE__), "locales")

        #index page of cron jobs
        app.get '/cron' do
          view_path    = File.join(File.expand_path("..", __FILE__), "views")

          @cron_jobs = Sidekiq::Cron::Job.all

          #if Slim renderer exists and sidekiq has layout.slim in views
          if defined?(Slim) && File.exists?(File.join(settings.views,"layout.slim"))
            render(:slim, File.read(File.join(view_path, "cron.slim")))
          else
            render(:erb, File.read(File.join(view_path, "cron.erb")))
          end
        end

        # display job detail + jid history
        app.get '/cron/:name' do
          view_path = File.join(File.expand_path("..", __FILE__), "views")

          @job = Sidekiq::Cron::Job.find(route_params[:name])
          if @job
            #if Slim renderer exists and sidekiq has layout.slim in views
            if defined?(Slim) && File.exists?(File.join(settings.views,"layout.slim"))
              render(:slim, File.read(File.join(view_path, "cron_show.slim")))
            else
              render(:erb, File.read(File.join(view_path, "cron_show.erb")))
            end
          else
            redirect "#{root_path}cron"
          end
        end

        #enque cron job
        app.post '/cron/:name/enque' do
          if route_params[:name] === '__all__'
            Sidekiq::Cron::Job.all.each(&:enque!)
          elsif job = Sidekiq::Cron::Job.find(route_params[:name])
            job.enque!
          end
          redirect params['redirect'] || "#{root_path}cron"
        end

        #delete schedule
        app.post '/cron/:name/delete' do
          if route_params[:name] === '__all__'
            Sidekiq::Cron::Job.all.each(&:destroy)
          elsif job = Sidekiq::Cron::Job.find(route_params[:name])
            job.destroy
          end
          redirect "#{root_path}cron"
        end

        #enable job
        app.post '/cron/:name/enable' do
          if route_params[:name] === '__all__'
            Sidekiq::Cron::Job.all.each(&:enable!)
          elsif job = Sidekiq::Cron::Job.find(route_params[:name])
            job.enable!
          end
          redirect params['redirect'] || "#{root_path}cron"
        end

        #disable job
        app.post '/cron/:name/disable' do
          if route_params[:name] === '__all__'
            Sidekiq::Cron::Job.all.each(&:disable!)
          elsif job = Sidekiq::Cron::Job.find(route_params[:name])
            job.disable!
          end
          redirect params['redirect'] || "#{root_path}cron"
        end

      end
    end
  end
end
