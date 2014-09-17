class conjur::host_identity (
  $certificate, $account, $name,
  $appliance,
  $token = undef, $key = undef
) {
  if ($token == undef) and ($key == undef) {
    fail "host factory token or host api key required"
  }

  $pemfile = "/etc/conjur-$account.pem"
  $netrcfile = '/etc/conjur.identity'

  file { $pemfile:
    content => $certificate
  }

  $config = {
    appliance_url => $appliance,
    account => $account,
    cert_file => $pemfile,
    netrc_path => $netrcfile
  }

  file { '/etc/conjur.conf':
    content => inline_template('<%= YAML.dump @config %>')
  }

  if $key == undef {
    $key = create_host($name, $token)
  }

  $identity = {
    machine => "$appliance/authn",
    login => "host/$name",
    password => $key
  }

  file { $netrcfile:
    content => template('conjur/netrc_entry.erb'),
    mode => '0600'
  }
}
