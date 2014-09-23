class conjur::host_identity inherits conjur {
  if ($hostfactory_token == undef) and ($host_key == undef) {
    fail "host factory token or host api key required"
  }

  if $host_key == undef {
    $create_host_identity = '/opt/conjur/bin/create-host-identity'

    package { 'conjur-asset-host-factory':
      provider => conjur_gem,
      require => Class['conjur::client']
    }

    file { $create_host_identity:
      content => file('conjur/create-host-identity.rb'),
      mode => '0755'
    }

    exec { 'create-host-identity':
      command => "$create_host_identity $host_conjurid $hostfactory_token",
      require => Class['conjur::client'],
      creates => $netrc_path
    }
  } else {
    $identity = {
      machine => "$conjur_url/authn",
      login => "host/$host_conjurid",
      password => $host_key
    }

    file { $netrc_path:
      content => template('conjur/netrc_entry.erb'),
      mode => '0600'
    }
  }
}
