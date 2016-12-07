File { backup => false }

node default {
  $db_password = conjur_secret('prod/inventory-db/password')

  notify { "Loaded db password: ${db_password}": }

  file { '/tmp/puppet-in-docker':
    ensure  => present,
    content => 'This file is for demonstration purposes only',
  }
}
