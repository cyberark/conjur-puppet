class conjur (
  $conjur_certificate = undef,
  $conjur_account = undef,
  $conjur_url = undef,

  $host_id = undef,
  $host_key = undef,
  $hostfactory_token = undef,

  $client_install = true,

  $certificate_path = "/etc/conjur-$conjur_account.pem",
  $netrc_path = '/etc/conjur.identity'
) {
  if $client_install {
    contain ::conjur::client
  }

  contain ::conjur::config
  contain ::conjur::host_identity
}
