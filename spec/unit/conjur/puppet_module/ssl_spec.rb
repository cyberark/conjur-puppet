# frozen_string_literal: true

require 'spec_helper'

require 'puppet/functions/conjur/util/ssl'

describe Conjur::PuppetModule::SSL do
  let(:host) { 'mock_host' }
  let(:ssl_certificate) { double 'ssl_certificate' }

  let(:valid_cert) { fixture_file('ssl/valid_cert.pem') }
  let(:valid_cert_1) { fixture_file('ssl/valid_cert_part1.pem').strip }
  let(:valid_cert_2) { fixture_file('ssl/valid_cert_part2.pem').strip }
  let(:bad_data_cert) { fixture_file('ssl/partially_valid_cert_bad_data.pem').strip }

  let(:valid_x509_cert_1) { double 'x509_cert_1' }
  let(:valid_x509_cert_2) { double 'x509_cert_2' }

  let(:mock_cert_store) { double 'cert_store' }

  before(:each) do
    allow(OpenSSL::X509::Store).to receive(:new)
      .and_return(mock_cert_store)
    allow(OpenSSL::X509::Certificate).to receive(:new)
      .with(anything)
      .and_raise('parsing error')
    allow(OpenSSL::X509::Certificate).to receive(:new)
      .with(valid_cert_1)
      .and_return(valid_x509_cert_1)
    allow(OpenSSL::X509::Certificate).to receive(:new)
      .with(valid_cert_2)
      .and_return(valid_x509_cert_2)

    allow(Puppet).to receive(:info)
  end

  it 'can parse certs' do
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_1)
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_2)

    expect(subject.load(valid_cert)).to eq(mock_cert_store)
  end

  it 'shows number of certs parsed' do
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_1)
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_2)
    expect(Puppet).to receive(:info).once.with %r{2 certificate\(s\)}

    expect(subject.load(valid_cert)).to eq(mock_cert_store)
  end

  it 'can parse certs with extra non-cert data' do
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_1)
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_2)

    untrimmed_cert = "\rblah\nifoo1@#$%^%$#@#{valid_cert}\rblah\nifoo1@#$%^%$#"

    expect(subject.load(untrimmed_cert)).to eq(mock_cert_store)
  end

  it 'can parse certs with non-standard line endings' do
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_1)
    expect(mock_cert_store).to receive(:add_cert).once.with(valid_x509_cert_2)

    windows_cert = valid_cert.gsub('\n', '\r\n')

    expect(subject.load(windows_cert)).to eq(mock_cert_store)
  end

  it 'throws error when cert had bad data' do
    expect { subject.load(bad_data_cert) }.to raise_error('parsing error')
  end

  it 'returns empty array and shows a warning if certificate is nil' do
    expect(Puppet).to receive(:warning).with %r{YOU ARE VULNERABLE}

    expect(subject.load(nil)).to eq([])
  end

  it 'returns empty array and shows a warning if certificate is empty' do
    expect(Puppet).to receive(:warning).with %r{YOU ARE VULNERABLE}

    expect(subject.load('')).to eq([])
  end
end
