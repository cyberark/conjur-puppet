class conjur::params {
  $conjur_config = $facts['conjur'].lest ||{{}}

  $account = $conjur_config['account']
  $appliance_url = $conjur_config['appliance_url']
  $authn_login = $conjur_config['authn_login']
  $authn_api_key = undef
  $ssl_certificate = $conjur_config['ssl_certificate']
  $authn_token = $conjur_config['token'].then |$token| {
    $token
  }.lest ||{$conjur_config['encrypted_token'].then |$token| {
    $token.conjur::decrypt
  }}
  $host_factory_token = undef
  $version = $conjur_config['version'].lest || { 4 }
}
