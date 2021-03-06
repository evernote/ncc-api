#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'rubygems'
require 'fileutils'
require 'ncc_spec_helper'
require 'noms/cmdb'
require 'ncc'

Fog.mock!
NOMS::CMDB.mock!

describe NCC::Connection do
    before(:all) { setup_fixture }
    after(:all) { cleanup_fixture }

    before :all do
        $logger = LogCatcher.new
        $ncc = NCC.new('test/data/etc')
    end

    {'awscloud' => 'AWS', 'openstack0' => 'OpenStack'}.each do |cloud, provider|

        context "in #{provider}" do

            it "establishes a new connection when config changes" do
                fog_id0 = $ncc.clouds(cloud).fog.object_id
                sleep 2
                FileUtils.touch "test/data/etc/clouds/#{cloud}.conf"
                fog_id1 = $ncc.clouds(cloud).fog.object_id
                fog_id0.should_not == fog_id1
            end

        end

    end

end
