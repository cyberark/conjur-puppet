Puppet::Functions.create_function :'conjur::config_yml' do
  dispatch :generate do
    param 'String', :appliance_url
    param 'Integer', :version
    optional_param 'Variant[String, Undef]', :account
    optional_param 'Variant[String, Undef]', :cert_file
  end

  # so much easier to do this in Ruby than in puppet
  def generate appliance_url, version, account, cert_file
    {
      appliance_url: appliance_url,
      version: version,
      account: account,
      cert_file: cert_file
    }.map do |key, value|
      next unless value
      [key, value].join ": "
    end.compact.join("\n") + "\n"
  end
end
