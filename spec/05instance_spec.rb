#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'rubygems'
require 'ncc_spec_helper'
require 'ncc'
require 'noms/cmdb'

NOMS::CMDB.mock!
Fog.mock!

describe NCC::Instance do

    before(:all)  { setup_fixture }
    after(:all) { cleanup_fixture }

    before :all do
        $ncc = NCC.new('test/data/etc')
        $cfg = $ncc.config

        $req = {
            'size' => 'm1.medium',
            'image' => 'centos5.6',
        }
        $inst_spec = {
            'name' => 'testname',
            'size' => 'm1.medium',
            'image' => 'centos5.6',
            'environment' => 'lab',
            'ip_address' => '10.0.0.2',
            'host' => 'm0002299'
        }
        $instance = NCC::Instance.new($cfg, $inst_spec)

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

        $aws = $ncc.clouds('awscloud')
        $aws_server = $aws.fog.servers.
            create(:image_id => $aws.images('centos5.6')['provider_id'],
            :flavor_id => $aws.sizes('m1.medium')['provider_id'],
            :name => 'testserver0')
        $aws_server.wait_for { ready? }

    end

    describe ".new" do

        subject { NCC::Instance.new($cfg, $inst_spec) }
        it { should be_a NCC::Instance }

        specify { $instance.name.should == 'testname' }
        specify { $instance.size.should == 'm1.medium' }
        specify { $instance.image.should == 'centos5.6' }
        specify { $instance.environment.should == 'lab' }
        specify { $instance.ip_address.should == '10.0.0.2' }
        specify { $instance.host.should == 'm0002299' }

    end

    describe "#with_defaults" do

        before :each do
            $instance = NCC::Instance.new($ncc.config,
                                      'name' => 'testname',
                                      'size' => 'm1.medium')
        end

        it "deeply merges extra options" do
            $instance.clear_extra
            $instance.extra = { 'aws' => { 'subnet_id' => 'subnet-123' } }
            $instance.extra['aws'].should have(1).items
            $instance.extra = { 'aws' => { 'availability_zone' =>
                    'us-east-1a' } }
            $instance.extra.should == { 'aws' => {
                    'subnet_id' => 'subnet-123',
                    'availability_zone' => 'us-east-1a' } }
        end

        it "doesn't overwrite existing options" do
            $instance.extra = { 'aws' => { 'subnet_id' => 'subnet-123' } }
            $instance.extra = { 'aws' => { 'subnet_id' => 'subnet-345' } }
            $instance.extra['aws']['subnet_id'].should == 'subnet-123'
        end

    end

    describe "#name" do
        it "should set name" do
            $instance.name = 'testname1'
            $instance.name.should == 'testname1'
        end
    end

    describe "#size" do
        it "should set size" do
            $instance.size = 'm1.xlarge'
            $instance.size.should == 'm1.xlarge'
        end

        it "should raise error when setting invalid size" do
            expect { $instance.size = 'nonsense' }.
                to raise_error NCC::Error, /Invalid size/
        end
    end

    describe "#image" do
        it "should set image" do
            $instance.image = 'win2k8.1'
            $instance.image.should == 'win2k8.1'
        end

        it "should raise error when setting invalid image" do
            expect { $instance.image = 'nonsense' }.
                to raise_error NCC::Error, /Invalid image/
        end
    end

    describe "#environment" do
        it "should set environment" do
            $instance.environment = 'testenv'
            $instance.environment.should == 'testenv'
        end
    end

    describe "#extra" do

        it "should set extra" do
            $instance.clear_extra
            extra_param = { 'openstack' => { 'param' => 'value' } }
            $instance.extra = extra_param.dup
            $instance.extra.should == extra_param
        end

        it "should raise error when setting something other than hash" do
            expect { $instance.extra = 'nonsense' }.
                to raise_error NCC::Error, /Invalid extra/
        end
    end

    describe "#status" do

        it "should set status" do
            $instance.status = 'active'
            $instance.status.should == 'active'
        end

        it "should raise error when setting invalid status" do
            expect { $instance.status = 'REVERT_RESIZE' }.
                to raise_error NCC::Error, /Invalid status/
        end

    end

    describe "#set_without_validation" do
        it "should set invalid field values" do
            $instance.set_without_validation(:image => 'nonsense')
            $instance.image.should == 'nonsense'
        end

        it "should set regular field values" do
            $instance.set_without_validation(:ip_address => '10.0.0.3',
                                  :host => 'm00002211')
            $instance.host.should == 'm00002211'
            $instance.ip_address.should == '10.0.0.3'
        end

        it "should reject fields not permitted to be set unvalidated" do
            expect do
                $instance.set_without_validation(:status => 'REVERT_RESIZE')
            end.to raise_error NCC::Error, /Invalid status/
        end
    end

    describe "#role" do

        it "should set a list value" do
            $instance.role = ['role1', 'role2']
            $instance.role.should =~ ['role2', 'role1']
        end

        it "should set a list value from a string" do
            $instance.role = 'role1'
            $instance.role.should be_an Array
        end

        it "should set a list value from a comma-separated string" do
            $instance.role = 'role1,role2'
            $instance.role.should be_an Array
            $instance.role.should =~ ['role2','role1']
        end

    end

end

describe NCC do

    describe "#instances" do

    end

end

describe NCC::Connection do

    before(:all)  { setup_fixture }
    after(:all) { cleanup_fixture }

    before :all do
        $logger = LogCatcher.new
        $ncc = NCC.new('test/data/etc', :logger => $logger)
        $aws = $ncc.clouds('awscloud')
        $os  = $ncc.clouds('openstack0')
        $aws.fog.register_image('centos5.6-aws', 'centos5.6-aws', '/dev/sda0')
        $aws_image_id =
            $aws.fog.images.find { |i| i.name == 'centos5.6-aws' }.id
        $ncc.config[:providers]['aws']['images']['centos5.6'] = $aws_image_id
        $os_image_id = $os.fog.images.first.id
        $ncc.config[:clouds]['openstack0']['images']['centos5.6'] =
            $os_image_id
    end

    describe "#map_to_id" do

        context "in AWS" do

            it "should map provider id to abstract id" do
                $aws.map_to_id(:image, $aws_image_id).should == 'centos5.6'
            end

            it "should leave unmappable id unmapped" do
                $aws.map_to_id(:size, 'ami-deadbeef').should == 'ami-deadbeef'
            end

        end

        context "in OpenStack" do

            it "should map provider id to abstract id" do
                $os.map_to_id(:image, $os_image_id).should == 'centos5.6'
            end

            it "should leave unmappable id unmapped" do
                unmap_id = '0ed3f171-91e7-49a6-9af9-d16fe8c34b95'
                $os.map_to_id(:image, unmap_id).should == unmap_id
            end

        end

    end

    describe "#instances" do

        before :all do
            image_id = $aws.images('centos5.6')['provider_id']
            flavor_id = $aws.sizes('m1.medium')['provider_id']
            $aws.fog.servers.each do |server|
                server.destroy
            end
            $aws_server = $aws.fog.servers.
                create(:name => 'test-aws-server-0',
                :flavor_id => flavor_id,
                :image_id => image_id,
                :tags => { 'Name' => 'test-aws-server-0' })
            $aws_server.wait_for { ready? }

        end

        context "in AWS" do

            context "for one instance" do

                before :each do
                    $instance = $aws.instances($aws_server.id)
                end

                specify { $aws.fog.servers.should have(1).items }
                specify { $instance.should be_a NCC::Instance }
                specify { $instance.id.should == $aws_server.id }
                specify { $instance.name.should == 'test-aws-server-0' }
                specify { $instance.size.should == 'm1.medium' }
                specify { $instance.image.should == 'centos5.6' }
                specify { $instance.status.should == 'active' }

            end

            context "when listing instances" do

                specify { $aws.instances.should have(1).items }

            end

        end

        context "in OpenStack" do

            # No tests here because mocking OpenStack instance
            # creation does not work in applicable versions of
            # fog (1.10) -jbrinkley/20130411

        end


    end

end
