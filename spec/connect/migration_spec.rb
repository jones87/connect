require 'spec_helper'

describe SUSE::Connect::Migration do
  describe '.system_products' do
    let(:zypper_product) { Zypper::Product.new(name: 'SLES', version: '12', arch: 'x86_64') }
    let(:remote_product) { Remote::Product.new(identifier: 'SLES', version: '12', arch: 'x86_64', release_type: 'HP-CNB') }

    it 'returns installed products and status activated products' do
      expect_any_instance_of(SUSE::Connect::Status).to receive(:system_products).and_return([Product.transform(zypper_product),
                                                                                             Product.transform(remote_product)])
      result = described_class.system_products
      expect(result).to match_array([Product.transform(zypper_product), Product.transform(remote_product)])
    end
  end

  describe '.rollback' do
    let(:config) { SUSE::Connect::Config.new }
    let(:client) { SUSE::Connect::Client.new(config) }
    let(:status) { SUSE::Connect::Status.new(config) }
    let(:service) do
      SUSE::Connect::Remote::Service.new(name: 'SLES12', obsoleted_service_name: 'SLES11',
                                         url: 'https://scc.suse.com', 'product' => { identifier: 'SLES' })
    end
    let(:installed_products) do
      [
        Zypper::Product.new(name: 'SLES', version: '12', arch: 'x86_64', isbase: 'true'),
        Zypper::Product.new(name: 'sle-module-legacy', version: '12', arch: 'x86_64')
      ]
    end

    it 'restores a state of the system before migration' do
      expect(SUSE::Connect::Config).to receive(:new).and_return config
      expect(SUSE::Connect::Client).to receive(:new).with(config).at_least(:once).and_return client
      expect(SUSE::Connect::Status).to receive(:new).with(config).and_return status

      expect(status).to receive(:installed_products).at_least(:once).and_return installed_products

      installed_products.each do |product|
        expect(client).to receive(:downgrade_product).with(product).and_return service
        expect(described_class).to receive(:remove_service).with(service.name)
        expect(described_class).to receive(:remove_service).with(service.obsoleted_service_name)
        expect(described_class).to receive(:add_service).with(service.url, service.name)
      end

      expect(client).to receive(:synchronize).with(installed_products).and_return true
      expect(SUSE::Connect::Zypper).to receive(:set_release_version).with('12').and_return true
      described_class.rollback
    end
  end

  describe '.enable_repository' do
    it 'enables zypper repository' do
      expect(SUSE::Connect::Zypper).to receive(:enable_repository).with('repository_name')
      described_class.enable_repository('repository_name')
    end
  end

  describe '.disable_repository' do
    it 'disables zypper repository' do
      expect(SUSE::Connect::Zypper).to receive(:disable_repository).with('repository_name')
      described_class.disable_repository('repository_name')
    end
  end

  describe '.repositories' do
    it 'calls underlying method of Zypper class' do
      expect(SUSE::Connect::Zypper).to receive(:repositories).and_return([])
      described_class.repositories
    end

    it 'returns an array of OpenStruct objects' do
      expect(SUSE::Connect::Zypper).to receive(:repositories).and_return([{ name: 'foo' }, { name: 'bar' }])
      expect(described_class.repositories.any? {|r| r.is_a?(OpenStruct) }).to be true
    end
  end

  describe '.add_service' do
    it 'forwards to zypper add_service' do
      service_url = 'http://bla.bla'
      service_name = 'bla'
      expect(SUSE::Connect::Zypper).to receive(:add_service).with(service_url, service_name)

      described_class.add_service(service_url, service_name)
    end
  end

  describe '.remove_service' do
    it 'forwards to zypper remove_service' do
      service_name = 'bla'
      expect(SUSE::Connect::Zypper).to receive(:remove_service).with(service_name)

      described_class.remove_service(service_name)
    end
  end

  describe '.find_products' do
    it 'finds the solvable products available on the system' do
      product_identifier = 'SLES'
      expect(SUSE::Connect::Zypper).to receive(:find_products).with(product_identifier).and_return([])
      described_class.find_products(product_identifier)
    end

    it 'returns an array of OpenStruct objects' do
      expect(SUSE::Connect::Zypper).to receive(:find_products).and_return([{ name: 'foo' }, { name: 'bar' }])
      expect(described_class.find_products('identifier').any? {|r| r.is_a?(OpenStruct) }).to be true
    end
  end

  describe '.install_release_package' do
    it 'installs release package by calling underlying method of Zypper class' do
      product_identifier = 'SLES'
      expect(SUSE::Connect::Zypper).to receive(:install_release_package).with(product_identifier).and_return([])
      described_class.install_release_package(product_identifier)
    end
  end
end
