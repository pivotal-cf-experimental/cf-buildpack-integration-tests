require 'spec_helper'

describe "Bugs", :ruby_buildpack do
  context "MRI 1.8.7" do
    xit "should install nokogiri" do
      Machete.deploy_app("mri_187_nokogiri", :ruby) do |app|
        expect(app).to be_staged
        expect(app.output).to match("Installing nokogiri")
        expect(app.output).to match("Your bundle is complete!")
      end
    end
  end
end
