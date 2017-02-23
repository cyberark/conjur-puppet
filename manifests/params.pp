class conjur::params {
  $conjur_config = $facts['conjur'].lest ||{{}}

  $appliance_url = $conjur_config['appliance_url']
  $authn_login = undef
  $authn_api_key = undef
  $ssl_certificate = $conjur_config['ssl_certificate']
  $authn_token = undef
  $host_factory_token = undef
}
