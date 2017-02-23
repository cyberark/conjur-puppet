Facter.add :conjur do
  setcode do
    if File.exist? '/etc/conjur.conf'
      c = YAML.load File.read '/etc/conjur.conf'
      c['ssl_certificate'] ||= File.read c['cert_file'] \
          if c['cert_file']
      c
    else
      {}
    end
  end
end
