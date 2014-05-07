require 'spec_helper'
require 'json'
require 'fileutils'

describe "Node version resolver" do

  # https://github.com/isaacs/node-semver

  let(:node_buildpack_path) { "#{ENV['BUILDPACK_ROOT'] || "../buildpacks"}/cf-buildpack-nodejs" }

  before do
    FileUtils.mkdir_p("#{node_buildpack_path}/tmp")
    FileUtils.cp_r("spec/fixtures/versions.json", "#{node_buildpack_path}/tmp/versions.json")
  end

  after do
    FileUtils.rm_f("#{node_buildpack_path}/tmp")
  end

  def resolve_version(version = "null")
    if `uname`.include?("Darwin")
      node_executable = "node"
    else
      node_executable = "#{node_buildpack_path}/bin/node"
    end

    `#{node_executable} #{node_buildpack_path}/lib/version_resolver.js "#{version}"`.strip
  end

  describe "supporting ranges" do
    it "resolves no version" do
      resolve_version.should == '0.10.27'
    end

    it { resolve_version('0.10.13').should == '0.10.13' }
    it { resolve_version('0.10.13+build2012').should eql '0.10.13' }
    it { resolve_version('>0.10.13').should eql '0.10.14' }
    it { resolve_version('<0.10.13').should eql '0.10.12' }
    it { resolve_version('>=0.10.14').should eql '0.10.14' }
    it { resolve_version('>=0.10.15').should eql '0.11.0' }
    it { resolve_version('<=0.10.14').should eql '0.10.14' }
    it { resolve_version('<=0.10.15').should eql '0.10.14' }

    describe "when there's a stable version in the range" do
      it { resolve_version('0.10.11 - 0.10.14').should eql '0.10.14' }
    end

    describe "when there isn't a stable version in the range" do
      it { resolve_version('0.10.30 - 0.13.0').should eql '0.11.0' }
    end

    it { resolve_version('~0.9.0').should eql '0.9.1' }
    it { resolve_version('^0.9').should eql '0.9.1' }
    it { resolve_version('^0.0.1').should eql '0.0.1' }
    it { resolve_version('0.10.x').should eql '0.10.14' }
    it { resolve_version('0.x').should eql '0.10.14' }
    it { resolve_version('x').should eql '0.10.14' }
    it { resolve_version('*').should eql '0.10.14' }
    it { resolve_version('').should eql '0.10.14' }
  end
end