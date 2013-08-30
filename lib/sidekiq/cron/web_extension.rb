module Sidekiq
  module Cron
    module WebExtension

      def self.registered(app)

        #very bad way of loading locales for cron jobs
        #should be rewritten
        app.helpers do

          alias_method :old_strings, :strings

          def strings
            #only on first load! 
            unless @strings
              #load all locales from Sidekiq
              old_strings

              Dir["#{File.join(File.expand_path("..", __FILE__), "locales")}/*.yml"].each do |file|
                YAML.load(File.open(file)).each do |locale, translations|
                  translations.each do |key, value|
                    @strings[locale][key] = value
                  end
                end
              end
            end
            @strings
          end
        end

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

        #enque cron job
        app.post '/cron/:name/enque' do |name|
          if job = Sidekiq::Cron::Job.find(name)
            job.enque!
          end
          redirect "#{root_path}cron"
        end

        #delete schedule
        app.post '/cron/:name/delete' do |name|
          if job = Sidekiq::Cron::Job.find(name)
            job.destroy
          end
          redirect "#{root_path}cron"
        end

        #enable job
        app.post '/cron/:name/enable' do |name|
          if job = Sidekiq::Cron::Job.find(name)
            job.enable!
          end
          redirect "#{root_path}cron"
        end

        #disable job
        app.post '/cron/:name/disable' do |name|
          if job = Sidekiq::Cron::Job.find(name)
            job.disable!
          end
          redirect "#{root_path}cron"
        end
        
      end
    end
  end
end
