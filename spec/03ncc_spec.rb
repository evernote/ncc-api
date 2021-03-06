#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'ncc_spec_helper'
require 'rubygems'
require 'ncc'
require 'fog'

Fog.mock!

describe NCC do

    before(:all)  { setup_fixture }
    after(:all)   { cleanup_fixture }
    before:each do
        $logger = LogCatcher.new
        $ncc = NCC.new('test/data/etc', :logger => $logger)
    end

    describe '.new' do
        specify { $ncc.should be_a NCC }
    end

    describe '#config' do
        specify { $ncc.config.should be_a NCC::Config }
    end

    describe '#clouds' do
        specify { $ncc.clouds.should have(2).items }
        specify { $ncc.clouds('awscloud').should be_a NCC::Connection }
        specify {
            expect($ncc.object_id).to eq $ncc.object_id
            expect($ncc.clouds('awscloud').object_id).to eq $ncc.clouds('awscloud').object_id
        }
    end

    describe '#sizes' do
        specify { $ncc.sizes.should have(7).items }
        specify { $ncc.sizes('m1.xlarge')['cores'].should == 8 }
        specify do
            $ncc.sizes(
                 'm1.xlarge')['description'].
                should == "8CPU 16GB RAM 400GB disk"
        end

        context "accessing AWS" do

            it "should report abstract sizes" do
                $ncc.clouds('awscloud').sizes.should be_a Array
                $ncc.clouds('awscloud').sizes('m1.xlarge').should be_a Hash
                $ncc.clouds('awscloud').sizes('m1.xlarge')['cores'].should == 8
                $ncc.clouds(
                     'awscloud').sizes(
                                 'm1.xlarge')['description'].
                    should == "Extra Large Instance"
                $ncc.clouds('awscloud').
                    sizes('m1.xlarge')['price'].should == 360
                $ncc.clouds('awscloud').
                    sizes('m1.xlarge')['special'].should == 'true'
            end

        end

        context "accessing OpenStack" do

            it "reports abstract sizes" do
                $ncc.clouds('openstack0').sizes.should be_a Array
                $ncc.clouds('openstack0').sizes('m1.large').should be_a Hash
                $ncc.clouds('openstack0').
                    sizes('m1.medium')['cores'].should == 8
                $ncc.clouds(
                     'openstack0').sizes(
                                   'm1.medium')['description'].
                    should == "8CPU 4GB RAM 161GB disk"
                $ncc.clouds('openstack0').
                    sizes('m1.medium')['price'].should == 16
            end

        end
    end

    describe "#images" do
        specify { $ncc.images.should have(3).items }
        specify { $ncc.images.should be_a Array }
        specify { $ncc.images('centos5.6')['osfamily'].should == 'RedHat' }

        before :all do
            $image_id = { }
            ['awscloud'].each do |cloud|
                $ncc.clouds(cloud).fog.
                    register_image('testimg', 'testimg', '/dev/sda0')
                image = $ncc.clouds(cloud).
                    fog.images.find { |i| i.name == 'testimg' }
                $image_id[cloud] = image.id
                p = $ncc.clouds(cloud).provider
                conf = $ncc.config[:providers][p].to_hash
                conf['images']['centos5.6'] = $image_id[cloud]
                File.open("test/data/etc/providers/#{p}.conf", 'w') do |fh|
                    fh << JSON.pretty_generate(conf)
                end
                $ncc.config[:providers][p].update_config
            end
        end

        context "accessing AWS" do

            it "should report abstract images" do
                $ncc.clouds('awscloud').images.should be_a Array
                $ncc.clouds('awscloud').images('centos5.6').should be_a Hash
                $ncc.clouds('awscloud').
                    images('centos5.6')['provider_id'].should ==
                    $image_id['awscloud']
                $ncc.clouds('awscloud').
                    images('centos5.6')['osfamily'].should == 'RedHat'
            end

        end

        context "accessing OpenStack" do

            it "should report abstract images" do
                $ncc.clouds('openstack0').images.should be_a Array
                $ncc.clouds('openstack0').
                    images('centos5.6').should be_a Hash
                $ncc.clouds('openstack0').
                    images('centos5.6')['osfamily'].should == 'RedHat'
            end

        end

    end

end
