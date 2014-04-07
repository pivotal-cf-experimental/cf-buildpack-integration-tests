require 'spec_helper'

describe "Bugs" do
  context "MRI 1.8.7" do
    it "should install nokogiri" do
      Machete.deploy_app("mri_187_nokogiri") do |app|
        expect(app.output).to match("Installing nokogiri")
        expect(app.output).to match("Your bundle is complete!")
      end
    end
  end
end
