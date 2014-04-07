require 'spec_helper'

describe 'deploying a rails 4 application' do
  xit 'make the homepage available' do
    Machete.deploy_app("rails_latest_web_app", {
      cmd: "bundle exec rake db:migrate && bundle exec rails s -p $PORT",
      with_db: true
    }) do |app|
      expect(app.homepage_html).to include('Listing people')
    end
  end
end
