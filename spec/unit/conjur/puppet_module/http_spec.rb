# frozen_string_literal: true

require 'spec_helper'

require 'conjur/puppet_module/http'

describe Conjur::PuppetModule::HTTP do
  def http_ok(body)
    Net::HTTPOK.new('1.1', '200', 'ok').tap do |resp|
      allow(resp).to receive(:body) { body }
    end
  end

  def http_unauthorized
    Net::HTTPUnauthorized.new '1.1', '403', 'unauthorized'
  end

  let(:host) { 'mock_host' }
  let(:port) { 12_345 }
  let(:target_url) { "https://#{host}:#{port}/" }
  let(:target_path) { 'my/path/to/resource' }

  let(:ssl_certificate) { 'ssl_certificate' }

  let(:mock_return_data) { double('my_retrieved_data') }
  let(:mock_connection) { double('conjur_connection') }
  let(:mock_cert_store) { double('cert_store') }

  before(:each) do
    allow(Conjur::PuppetModule::SSL).to receive(:load).with(ssl_certificate)
                                                      .and_return(mock_cert_store)
    allow(Net::HTTP).to receive(:start).with(host, port,
                                             hash_including(use_ssl: true,
                                                            cert_store: mock_cert_store))
                                       .and_yield(mock_connection)
  end

  describe 'get()' do
    let(:token) { 'my_supersecret_token' }
    let(:header_with_encoded_token) do
      { 'Authorization' => 'Token token="bXlfc3VwZXJzZWNyZXRfdG9rZW4="' }
    end

    it 'can retrieve data' do
      expect(mock_connection).to receive(:get).with('/' + target_path, header_with_encoded_token)
                                              .and_return(http_ok(mock_return_data))

      expect(subject.get(target_url, target_path, ssl_certificate, token))
        .to eq(mock_return_data)
    end

    it 'handles retrieval errors' do
      expect(mock_connection).to receive(:get).with('/' + target_path, header_with_encoded_token)
                                              .and_return(http_unauthorized)

      expect { subject.get(target_url, target_path, ssl_certificate, token) }
        .to raise_error Net::HTTPError
    end

    it 'does not include token if none is provided' do
      expect(mock_connection).to receive(:get).with('/' + target_path, {})
                                              .and_return(http_ok(mock_return_data))

      expect(subject.get(target_url, target_path, ssl_certificate, nil))
        .to eq(mock_return_data)
    end

    it 'can handle target url without slash' do
      expect(mock_connection).to receive(:get).with('/' + target_path, header_with_encoded_token)
                                              .and_return(http_ok(mock_return_data))

      expect(subject.get(target_url.delete_suffix('/'), target_path, ssl_certificate, token))
        .to eq(mock_return_data)
    end

    it 'sets use_ssl=false if schema is "http"' do
      allow(Net::HTTP).to receive(:start).with(host, port,
                                               hash_including(use_ssl: false,
                                                              cert_store: mock_cert_store))
                                         .and_yield(mock_connection)
      expect(mock_connection).to receive(:get).with('/' + target_path, header_with_encoded_token)
                                              .and_return(http_ok(mock_return_data))

      expect(subject.get(target_url.sub('https', 'http'), target_path, ssl_certificate, token))
        .to eq(mock_return_data)
    end

    it 'bubbles up errors from SSL cert parsing module' do
      allow(Conjur::PuppetModule::SSL).to receive(:load).with(ssl_certificate)
                                                        .and_raise 'bad certs'
      expect { subject.get(target_url.sub('https', 'http'), target_path, ssl_certificate, token) }
        .to raise_error 'bad certs'
    end
  end

  describe 'post()' do
    let(:mock_post_data) { 'post_data' }

    it 'can retrieve data' do
      expect(mock_connection).to receive(:post).with('/' + target_path, mock_post_data)
                                               .and_return(http_ok(mock_return_data))

      expect(subject.post(target_url, target_path, ssl_certificate, mock_post_data))
        .to eq(mock_return_data)
    end

    it 'handles retrieval errors' do
      expect(mock_connection).to receive(:post).with('/' + target_path, mock_post_data)
                                               .and_return(http_unauthorized)

      expect { subject.post(target_url, target_path, ssl_certificate, mock_post_data) }
        .to raise_error Net::HTTPError
    end

    it 'raises an error if data is empty' do
      expect { subject.post(target_url, target_path, ssl_certificate, nil) }
        .to raise_error ArgumentError
    end

    it 'can handle target url without slash' do
      expect(mock_connection).to receive(:post).with('/' + target_path, mock_post_data)
                                               .and_return(http_ok(mock_return_data))

      expect(subject.post(target_url.delete_suffix('/'), target_path, ssl_certificate, mock_post_data))
        .to eq(mock_return_data)
    end

    it 'sets use_ssl=false if schema is "http"' do
      allow(Net::HTTP).to receive(:start).with(host, port,
                                               hash_including(use_ssl: false,
                                                              cert_store: mock_cert_store))
                                         .and_yield(mock_connection)
      expect(mock_connection).to receive(:post).with('/' + target_path, mock_post_data)
                                               .and_return(http_ok(mock_return_data))

      expect(subject.post(target_url.sub('https', 'http'), target_path, ssl_certificate, mock_post_data))
        .to eq(mock_return_data)
    end

    it 'bubbles up errors from SSL cert parsing module' do
      allow(Conjur::PuppetModule::SSL).to receive(:load).with(ssl_certificate)
                                                        .and_raise 'bad certs'
      expect {
        subject.post(target_url.sub('https', 'http'),
                     target_path,
                     ssl_certificate,
                     mock_post_data)
      }.to raise_error 'bad certs'
    end
  end
end
