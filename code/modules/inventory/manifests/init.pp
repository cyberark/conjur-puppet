class inventory {
  file { '/dev/shm/etc':
    ensure => 'directory',
  }

  file { '/etc/inventory.conf':
    ensure => 'link',
    target => '/dev/shm/etc/inventory.conf',
  }

  $db_password = conjur_secret('prod/inventory-db/password')

  file { '/dev/shm/etc/inventory.conf':
    ensure  => present,
    content => template('inventory/inventory.conf.erb'),
  }
}

