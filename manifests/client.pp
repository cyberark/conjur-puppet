class conjur::client {
  package { conjur:
    provider => rpm,
    source => 'https://s3.amazonaws.com/conjur-releases/omnibus/conjur-4.13.1-1.x86_64.rpm'
  }
}
