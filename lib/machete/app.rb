require 'httparty'
require 'machete/system_helper'
require 'json'
require 'pry'

module Machete
  class App
    include SystemHelper

    attr_reader :output, :app_name, :manifest, :vendor_gems_before_push

    def initialize(app_name, language, opts={})
      @app_name = app_name
      @language = language
      @cmd = opts.fetch(:cmd, '')
      @with_pg = opts.fetch(:with_pg, false)
      @manifest = opts.fetch(:manifest, nil)
      @vendor_gems_before_push = opts.fetch(:vendor_gems_before_push, false)

      test_dependencies
    end

    def directory_for_app
      fixtures_dir = Dir.exists?("cf_spec") ? "cf_spec/fixtures" : "test_applications/#{@language}"
      if @language == :go
        "#{fixtures_dir}/#{app_name}/src/#{app_name}"
      else
        "#{fixtures_dir}/#{app_name}"
      end
    end

    def push()
      Dir.chdir(directory_for_app) do
        generate_manifest

        if vendor_gems_before_push
          Machete.logger.action('Vendoring gems before push')
          Bundler.with_clean_env do
            run_cmd('bundle package --all')
          end
        end

        run_cmd("cf delete -f #{app_name}")
        if with_pg?
          command = "cf push #{app_name} -b #{buildpack_name}"
          command += " -c '#{@cmd}'" if @cmd
          run_cmd("#{command} --no-start")
          run_cmd("cf bind-service #{app_name} lilelephant")
          run_cmd(command)
        else
          command = "cf push #{app_name} -b #{buildpack_name}"
          command += " -c '#{@cmd}'" if @cmd
        end
        @output = run_cmd(command)

        Machete.logger.info "Output from command: #{command}\n" +
          @output
      end
    end

    def staging_log
      run_cmd("cf files #{app_name} logs/staging_task.log")
    end

    def homepage_html
      HTTParty.get("http://#{url}").body
    end

    def url
      run_cmd("cf app #{app_name} | grep url").split(' ').last
    end

    def staged?
      raw_spaces = run_cmd('cf curl /v2/spaces')
      spaces = JSON.parse(raw_spaces)
      test_space = spaces['resources'].detect { |resource| resource['entity']['name'] == 'integration' }
      apps_url = test_space['entity']['apps_url']

      raw_apps = run_cmd("cf curl #{apps_url}")
      apps = JSON.parse(raw_apps)
      app = apps['resources'].detect { |resource| resource['entity']['name'] == app_name }
      app['entity']['package_state'] == 'STAGED'
    end

    def logs
      run_cmd("cf logs #{app_name} --recent")
    end

    def with_pg?
      @with_pg
    end

    private

    def test_dependencies
      test_services_exist if with_pg?
    end

    def test_services_exist
      services = `cf services`

      unless services =~ /^lilelephant/
        Machete.logger.warn("Could not find 'lilelephant' service in current cf space")
        Machete.logger.warn('Output was: ')
        Machete.logger.warn(services)
        exit(1)
      end
    end

    def buildpack_name
      "#{@language}-test-buildpack"
    end

    def generate_manifest
      return unless manifest

      File.open('manifest.yml', 'w') do |manifest_file|
        manifest_file.write @manifest.to_yaml
      end
    end

    def app_path
      if @language == :go
        "test_applications/go/src/#{app_name}"
      else
        "test_applications/#{@language}/#{app_name}"
      end
    end
  end
end
