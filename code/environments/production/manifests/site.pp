File { backup => false }

class inventory {
  $db_password = conjur_secret('prod/inventory-db/password')

  notify { "Installing DB password: ${db_password}": }
}

node default {
  file { '/tmp/puppet-in-docker':
    ensure  => present,
    content => 'This file is for demonstration purposes only',
  }
}

hiera_include('classes')
