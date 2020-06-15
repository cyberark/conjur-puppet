File { backup => false }

node default {
  file { '/tmp/puppet-in-docker':
    ensure  => present,
    content => 'This file is for demonstration purposes only',
  }

  if ($facts['conjur_smoke_test']) {
    notify { "Including conjur module...": }
    include conjur

    notify { "Grabbing 'inventory/db-password' secret...": }
    $secret = conjur::secret('inventory/db-password')

    notify { "Writing secret '${secret.unwrap}' to /tmp/test.pem...": }
    file { '/tmp/test.pem':
      ensure  => file,
      content => conjur::secret('inventory/db-password'),
    }

    notify { "Done!": }
  }
}
