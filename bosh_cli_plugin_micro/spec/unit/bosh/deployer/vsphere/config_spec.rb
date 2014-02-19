require 'spec_helper'

describe Bosh::Deployer::Config do
  let(:configuration_fixture) do
    Psych.load_file(spec_asset('test-bootstrap-config.yml')).merge('dir' => @dir)
  end
  let(:configuration_hash) { configuration_fixture }

  before do
    @dir = Dir.mktmpdir('bdc_spec')
    described_class.configure(configuration_hash)
  end

  after { FileUtils.remove_entry_secure @dir }

  it 'should default agent properties' do

    properties = described_class.cloud_options['properties']
    properties['agent'].should be_kind_of(Hash)
    properties['agent']['mbus'].start_with?('https://').should be(true)
    properties['agent']['blobstore'].should be_kind_of(Hash)
  end

  it 'should default vm env properties' do
    env = described_class.env
    env.should be_kind_of(Hash)
    env.should have_key('bosh')
    env['bosh'].should be_kind_of(Hash)
    env['bosh']['password'].should be_nil
  end

  it 'should contain default vm resource properties' do
    resources = described_class.resources
    resources.should be_kind_of(Hash)

    resources['persistent_disk'].should be_kind_of(Integer)

    cloud_properties = resources['cloud_properties']
    cloud_properties.should be_kind_of(Hash)

    %w(ram disk cpu).each do |key|
      cloud_properties[key].should_not be_nil
      cloud_properties[key].should be > 0
    end
  end

  it 'should configure agent using mbus property' do
    agent = described_class.agent
    agent.should be_kind_of(Bosh::Agent::HTTPClient)
  end

  describe '.networks' do
    context 'when additional networks are specified' do
      let(:configuration_hash) do
        configuration_fixture.merge('deployment_network' => 'deployment network')
      end

      it 'includes the default bosh network and the deployment network' do
        networks = described_class.networks
        expect(networks['bosh']['default']).to match_array(%w(dns gateway))
        %w(cloud_properties netmask gateway ip dns type).each do |key|
          networks['bosh'][key].should eq(configuration_hash['network'][key])
        end

        expect(networks).to include('deployment' => 'deployment network')
      end
    end

    context 'when additional networks are not specified' do
      it 'should map network properties to the bosh network' do
        networks = described_class.networks
        net = networks['bosh']
        net.should be_kind_of(Hash)
        expect(net['default']).to match_array(%w(dns gateway))
        %w(cloud_properties netmask gateway ip dns type).each do |key|
          net[key].should eq(configuration_hash['network'][key])
        end
      end
    end

    context 'when a vip is specified' do
      let(:configuration_hash) do
        configuration_fixture.tap do |h|
          h['network']['vip'] = '192.168.1.1'
        end
      end

      it 'includes the default bosh network and a vip network' do
        networks = described_class.networks
        expect(networks['bosh']['default']).to match_array(%w(dns gateway))
        %w(cloud_properties netmask gateway ip dns type).each do |key|
          networks['bosh'][key].should eq(configuration_hash['network'][key])
        end

        vip_hash = { 'vip' => { 'ip' => '192.168.1.1', 'type' => 'vip', 'cloud_properties' => {} } }
        expect(networks).to include(vip_hash)
      end
    end
  end
end
