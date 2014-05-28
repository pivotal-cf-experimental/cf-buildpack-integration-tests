require 'machete/logger'
require 'machete/app'
require 'machete/buildpack_uploader'
require 'machete/buildpack_mode'
require 'machete/firewall'

module Machete
  class << self
    def deploy_app(app_path, options={}, &block)
      app = Machete::App.new(app_path, options)
      app.push
      block.call(app)
    end

    def logger
      @logger ||= Machete::Logger.new(STDOUT)
    end

    def logger=(new_logger)
      @logger = new_logger
    end
  end
end

