package { 'activesupport':
  ensure   => '4.2.7.1',
  provider => puppetserver_gem,
}

package { 'conjur-api':
  ensure   => present,
  provider => puppetserver_gem,
}
