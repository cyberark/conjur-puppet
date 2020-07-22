# Responsible for storing Conjur connection information in the
# Windows registry.
class conjur::config::registry inherits conjur {

  registry_key { 'HKLM\Software\CyberArk\Conjur':
    ensure => present,
  }

  if $conjur::raw_ssl_certificate {
    registry_value { 'HKLM\Software\CyberArk\Conjur\SslCertificate':
      ensure => present,
      type   => string,
      data   => $conjur::raw_ssl_certificate,
    }
  }

  registry_value { 'HKLM\Software\CyberArk\Conjur\ApplianceUrl':
    ensure => present,
    type   => string,
    data   => $conjur::appliance_url,
  }

  registry_value { 'HKLM\Software\CyberArk\Conjur\Account':
    ensure => present,
    type   => string,
    data   => $conjur::authn_account,
  }

  registry_value { 'HKLM\Software\CyberArk\Conjur\Version':
    ensure => present,
    type   => dword,
    data   => $conjur::version,
  }
}
