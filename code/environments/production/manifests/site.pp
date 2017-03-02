File { backup => false }

node default {
  file { '/tmp/puppet-in-docker':
    ensure  => present,
    content => 'This file is for demonstration purposes only',
  }

  if ($facts['conjur_smoke_test']) {
    include conjur
    $secret = conjur::secret('inventory/db-password')
    notify {"Writing this secret to file: ${secret.unwrap}":}
    file { '/tmp/test.pem':
      content => conjur::secret('inventory/db-password'),
      ensure => file,
    }
  }
}
