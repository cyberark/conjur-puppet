class { 'conjur':
  appliance_url => 'https://conjur.test/api',
  authn_token   => Sensitive('the token'),
  account       => 'testacct',
  version       => $conjur_version,
}
