class conjur::config inherits conjur {
  file { $certificate_path:
    content => $conjur_certificate
  }

  $config = {
    appliance_url => $conjur_url,
    account => $conjur_account,
    cert_file => $certificate_path,
    netrc_path => $netrc_path
  }

  file { '/etc/conjur.conf':
    content => inline_template('<%= YAML.dump @config %>')
  }
}
