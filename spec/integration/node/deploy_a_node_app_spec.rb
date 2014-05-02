require "spec_helper"

describe 'deploying a nodejs app', :node_buildpack do
  it "makes the homepage available" do
    Machete.deploy_app("node_web_app", :nodejs, {
      cmd: "node server.js"
    }) do |app|
      expect(app).to be_staged
      expect(app.homepage_html).to include "Hello, World!"
    end
  end
end
