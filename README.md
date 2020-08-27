# conjur

[![Version](https://img.shields.io/puppetforge/v/cyberark/conjur.svg)](https://forge.puppet.com/cyberark/conjur)

#### Table of Contents

- [Description](#description)
- [Setup](#setup)
  * [Setup requirements](#setup-requirements)
  * [Deprecations](#deprecations)
    + [Puppet v5](#puppet-v5)
    + [Conjur Enterprise v4](#conjur-enterprise-v4)
    + [Use of Host Factory Tokens](#use-of-host-factory-tokens)
  * [Installation](#installation)
    + [Certified Versions](#certified-versions)
  * [Using conjur-puppet with Conjur OSS](#using-conjur-puppet-with-conjur-oss)
  * [Conjur module basics](#conjur-module-basics)
    + [Sensitive data type](#sensitive-data-type)
- [Usage](#usage)
  * [Methods to establish Conjur host identity](#methods-to-establish-conjur-host-identity)
    + [Conjur host identity with API key](#conjur-host-identity-with-api-key)
      * [Updating the Puppet manifest](#updating-the-puppet-manifest)
      * [Using Hiera](#using-hiera)
      * [Using Conjur identity files (Linux agents only)](#using-conjur-identity-files--linux-agents-only-)
      * [Using Windows Registry / Windows Credential Manager (Windows agents only)](#using-windows-registry---windows-credential-manager--windows-agents-only-)
- [Reference](#reference)
- [Limitations](#limitations)
- [Contributing](#contributing)
- [Support](#support)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

## Description

This is the official Puppet module for [Conjur](https://www.conjur.org), a robust
identity and access management platform. This module simplifies the operations involved in
establishing a Conjur host identity and allows authorized Puppet nodes to fetch
secrets from Conjur.

You can find our official distributable releases on Puppet Forge under [`cyberark/conjur`](https://forge.puppet.com/cyberark/conjur).

## Setup

### Setup requirements

This module requires that you have:
- Puppet v6 _or equivalent EE version_ (**Preliminary [Community level](https://github.com/cyberark/community/blob/master/Conjur/conventions/certification-levels.md#community)
  support only**)
- Conjur endpoint available to both the Puppet server and the Puppet nodes using this
  module. Supported versions:
  - Conjur OSS v1+
  - DAP v10+

### Deprecations

#### Puppet v5

Puppet v5 is not supported in v3+ of this module. If you are still using this version,
please use the [v2](https://github.com/cyberark/conjur-puppet/tree/v2) branch of this
project or a release version `<3.0.0`.

#### Conjur Enterprise v4

Conjur Enterprise v4 is not supported in v3+ of this module. If you are still using this
version, please use the [v2](https://github.com/cyberark/conjur-puppet/tree/v2) branch
of this project or a release version `<3.0.0`.

#### Use of Host Factory Tokens

Establishment of identity using host factory tokens directly through this module is no
longer supported. Host factory tokens can still be used to create host identities, but
these identities need to be established outside of the module itself. If you are still
using the creation of identities with host factory tokens via this module, please use
the [v2](https://github.com/cyberark/conjur-puppet/tree/v2) branch of this project or
a release version `<3.0.0`.

### Installation

To install this module, run the following command on the Puppet server:
```
puppet module install cyberark-conjur
```

To install a specific version of this module (e.g. `v1.2.3`), run the following
command on the Puppet server:
```
puppet module install cyberark-conjur --version 1.2.3
```

#### Certified Versions

Releases of this module belonging to the `v3` major version are not currently
certified. If a certified version of this module is desired, please use the highest
available `v2.x.x` version available on PuppetForge under
[`cyberark/conjur`](https://forge.puppet.com/cyberark/conjur).

### Using conjur-puppet with Conjur OSS

Are you using this project with [Conjur OSS](https://github.com/cyberark/conjur)? Then we
**strongly** recommend choosing the version of this project to use from the latest [Conjur OSS
suite release](https://docs.conjur.org/Latest/en/Content/Overview/Conjur-OSS-Suite-Overview.html).
Conjur maintainers perform additional testing on the suite release versions to ensure
compatibility. When possible, upgrade your Conjur version to match the
[latest suite release](https://docs.conjur.org/Latest/en/Content/ReleaseNotes/ConjurOSS-suite-RN.htm);
when using integrations, choose the latest suite release that matches your Conjur version. For any
questions, please contact us on [Discourse](https://discuss.cyberarkcommons.org/c/conjur/5).

### Conjur module basics

This module provides a `conjur::secret` [`Deferred` function](https://puppet.com/docs/puppet/6.17/deferring_functions.html)
that can be used to retrieve secrets from Conjur. Given a Conjur variable identifier and optional
identity parameters, `conjur::secret` uses the node’s Conjur identity to resolve and return
the variable’s value as a `Sensitive` variable.

Using agent-side identity:

```puppet
$dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password']))
```

Using server-provided configuration:
```puppet
$sslcert = @("EOT")
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
|-EOT

$dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password', {
  appliance_url => "https://my.conjur.org",
  account => "myaccount",
  authn_login => "host/myhost",
  authn_api_key => Sensitive("2z9mndg1950gcx1mcrs6w18bwnp028dqkmc34vj8gh2p500ny1qk8n"),
  ssl_certificate => $sslcert
}]))
```

#### Sensitive data type

Note `conjur::secret` returns values wrapped in a `Sensitive` data type. In
some contexts, such as string interpolation, it might cause surprising results
(interpolating to `Sensitive [value redacted]`). This is intentional, as it
makes it more difficult to accidentally mishandle secrets.

To use a secret as a string, you need to explicitly request it using the
`unwrap` function; the result of the processing should be again wrapped in
a `Sensitive` value.

In particular, you should not pass unwrapped secrets as resource parameters
if you can avoid it. Many resource types support `Sensitive` data type and
handle it correctly. If a resource you're using does not, file a bug.

```puppet
$dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password']))

# Use Sensitive data type to handle anything sensitive
$db_yaml = Sensitive("password: ${dbpass.unwrap}")

file { '/etc/someservice/db.yaml':
  ensure  => file,
  content => $db_yaml, # this correctly handles both Sensitive and String
  mode    => '0600' # remember to limit reading
}
```

## Usage

This module provides the `conjur::secret` function described above and the `conjur`
class, which can be configured to establish Conjur host identity on the node running
Puppet.

### Methods to establish Conjur host identity

Conjur requires an
[application identity](https://docs.conjur.org/Latest/en/Content/Get%20Started/key_concepts/machine_identity.html)
for any applications, machines, or processes that need to interact with Conjur.

Please note that before getting started configuring your Puppet environment, you'll need
to load a policy in Conjur to define the application identities that you will be using to
authenticate to Conjur. To learn more about
[creating hosts](https://docs.conjur.org/Latest/en/Content/Operations/Policy/statement-ref-host.htm),
please see [the Conjur documentation](https://docs.conjur.org/Latest/en/Content/Resources/_TopNav/cc_Home.htm).

In the sections below, we'll outline the different methods of providing this
module with your Conjur configuration and credentials. In those sections we'll
refer often to the following Conjur configuration variables:

- `appliance_url`: The URL of the Conjur or DAP instance you are connecting to. If using
  DAP, this may be the URL of a load balancer for the cluster's DAP follower instances.
- `account` - the account name for the Conjur / DAP instance you are connecting to.
- `authn_login`: The identity you are using to authenticate to the Conjur / DAP
  instance. For hosts / application identities, the fully qualified path should be prefixed
  by `host/`, eg `host/production/my-app-host`.
- `authn_api_key`: The API key of the identity you are using to authenticate to the
  Conjur / DAP instance.
- `ssl_certificate`: The _raw_ PEM-encoded x509 CA certificate chain for the DAP instance you
  are connecting to, provided as a string (including newlines) or using the
  [Puppet file resource type](https://puppet.com/docs/puppet/latest/types/file.html).
  This value may be obtained by running the command:
  ```sh-session
  $ openssl s_client -showcerts -servername [DAP_INSTANCE_DNS_NAME] \
    -connect [DAP_INSTANCE_DNS_NAME]:443 < /dev/null 2> /dev/null \
    | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'
  -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
  ```
- `version` (optional): Conjur API version, defaults to 5.

_Note that not all variables are required for each method of configuration._

#### Conjur host identity with API key

The simplest way to get started with a Conjur application identity is to
[create a host in Conjur](https://docs.conjur.org/Latest/en/Content/Operations/Policy/statement-ref-host.htm)
and then provide its Conjur credentials to this module. There are a few ways to provide
the Conjur Puppet module with these credentials and they are outlined in
the following sections.

##### Updating the Puppet manifest

When you update the Puppet manifest to include the Conjur host identity and API key, you
are configuring the Puppet **server** with the Conjur identity information.

In this example, after you have created a Conjur host named `redis001`, you can add
its host identity information and its API key to your `Deferred` invocation as an optional
hash like this:
```puppet
$sslcert = @("EOT")
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
|-EOT

$dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password', {
  appliance_url => "https://my.conjur.org",
  account => "default",
  authn_login => "host/redis001",
  authn_api_key => Sensitive("2z9mndg1950gcx1mcrs6w18bwnp028dqkmc34vj8gh2p500ny1qk8n"),
  ssl_certificate => $sslcert
}]))
```

##### Using Hiera

You can also add the Conjur identity configuration to Hiera, which provides the Conjur
identity information to the Puppet **server**. You then would use that information to
populate the host identity information:

```yaml
---
lookup_options:
  '^conjur::authn_api_key':
    convert_to: 'Sensitive'

conjur::account: 'default'
conjur::appliance_url: 'https://my.conjur.org'
conjur::authn_login: 'host/myhost'
conjur::authn_api_key: '<REPLACE_ME>'
conjur::ssl_certificate: |
  -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
```

Then in your manifest, you can fetch the secret like this:
```puppet
$sslkey = Sensitive(Deferred(conjur::secret, ["domains/%{hiera('domain')}/ssl-cert", {
  appliance_url => lookup('conjur::appliance_url'),
  account => lookup('conjur::account'),
  authn_login => lookup('conjur::authn_login'),
  authn_api_key => lookup('conjur::authn_api_key'),
  ssl_certificate => lookup('conjur::ssl_certificate')
}]))

file { '/abslute/path/to/cert.pem':
  ensure    => file,
  content   => $sslkey,
}
```

##### Using Conjur identity files (Linux agents only)

To configure **Linux agents** with a Conjur host identity, you can add the Conjur host
and API key to
[Conjur identity files](https://docs.conjur.org/Latest/en/Content/Get%20Started/key_concepts/machine_identity.html)
`/etc/conjur.conf` and `/etc/conjur.identity`.

Using the same `redis001` host as above, you would create a `conjur.conf` file that
contains:
```yaml
---
account: myorg
plugins: []
appliance_url: https://conjur.mycompany.com
cert_file: "/absolute/path/to/conjur-ca.pem" # Read from the Puppet agent
```

and a `conjur.identity` file that contains:
```netrc
machine conjur.mycompany.com
    login host/redis001
    password f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3
```

_**NOTE: The `conjur.conf` and `conjur.identity` files contain sensitive
  Conjur connection information. Care must be taken to ensure that
  the permissions for these files are set to `600` to
  disallow any access to these files by unauthorized (non-root) users
  on a Linux Puppet agent node.**_

The Conjur Puppet Module automatically checks for these files on your node and uses them if they
are available.

To then fetch your credential, you would use the default form of `conjur::secret`:
```puppet
$dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password']))
```

##### Using Windows Registry / Windows Credential Manager (Windows agents only)

To configure **Windows agents** with a Conjur host identity, you set up the Conjur
configuration in the Windows Registry and in the Windows Credential Manager. The
Registry contains the connection general information and the Credential Manager is
used to store the sensitive authentication credentials.

Connection settings for Conjur are stored in the Windows Registry under the key
`HKLM\Software\CyberArk\Conjur`. This is equivalent to `/etc/conjur.conf` on Linux. The
values available to set are:

| Value Name | Value Type | Description |
|-|-|-|
| `Account` | `REG_SZ` | Conjur account specified during Conjur setup. |
| `ApplianceUrl` | `REG_SZ` | Conjur API endpoint. |
| `SslCertificate` | `REG_SZ` | Public Conjur SSL cert. Overwritten by the contents read from `CertFile` when it is present. |
| `Version` | `REG_DWORD` | Conjur API version. Defaults to `5`. |

These may be set using Powershell (**use either `SslCertificate` _or_ `CertFile` but not both**):

```powershell
> reg ADD HKLM\Software\CyberArk\Conjur /v ApplianceUrl /t REG_SZ /d https://conjur.mycompany.com
> reg ADD HKLM\Software\CyberArk\Conjur /v Version /t REG_DWORD /d 5
> reg ADD HKLM\Software\CyberArk\Conjur /v Account /t REG_SZ /d myorg
> reg ADD HKLM\Software\CyberArk\Conjur /v SslCertificate /t REG_SZ /d "-----BEGIN CERTIFICATE-----..."
```

Or using a `.reg` registry file (**use either `SslCertificate` _or_ `CertFile` but not both**):
```reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\CyberArk\Conjur]
"ApplianceUrl"="https://conjur.mycompany.com"
"Version"=dword:00000005
"Account"="myorg"
"SslCertificate"="-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----"
```

_**NOTE: It is important from a security perspective to ensure that
unauthorized, non-administrator users do not have write access to Conjur
connection settings in the Windows Registry. Disabling write access for
unauthorized users to these settings will help to prevent potential malicious
redirection of sensitive Puppet agent messages. Read-only access for
non-administrator users to Conjur connection information can be confirmed via
`regedit` on the Windows Desktop, or by running the following command from a
PowerShell to confirm that only the `ReadKey` flag is set:**_

```powershell
PS C:\> Get-Acl -Path HKLM:SOFTWARE\CyberArk\Conjur | fl * | Out-String -stream | Select-String "BUIL
TIN\\Users"

AccessToString          : BUILTIN\Users Allow  ReadKey
```

Credentials for Conjur are stored in the Windows Credential Manager. The credential
`Target` is the Conjur appliance URL (e.g. `https://conjur.mycompany.com`).
The username is the host ID, with a `host/` prefix (e.g. `host/redis001`, as in previous
examples) and the credential password is the host's API key. This is equivalent to
`/etc/conjur.identity` on Linux.

This may be set using Powershell:
```powershell
> cmdkey /generic:https://conjur.mycompany.com /user:host/redis001 /pass
Enter the password for 'host/my-host' to connect to 'https://conjur.net/authn': #
{Prompt for API Key}

CMDKEY: Credential added successfully.
```

To then fetch your credential, you would use the default form of `conjur::secret`:
```puppet
$dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password']))
```

## Reference

For a complete reference, please see [REFERENCE.md](REFERENCE.md).

## Limitations

See [metadata.json](metadata.json) for supported platforms.

At current, the Conjur Puppet module encrypts and decrypts the Conjur access
token using the Puppet server’s private/public key pair. This is known to be
incompatible with using multiple [compile masters](https://puppet.com/docs/puppetserver/5.3/scaling_puppet_server.html).

## Contributing

We welcome contributions of all kinds to this repository. For instructions on
how to get started and descriptions of our development workflows, please see our
[contributing guide][contrib].

[contrib]: https://github.com/cyberark/conjur-puppet/blob/master/CONTRIBUTING.md

## Support

Please note, that this is a "Partner Supported" module, which means that technical
customer support for this module is solely provided by CyberArk.

Puppet does not provide support for any Partner Supported modules. For technical
support please visit the Conjur channnel at [CyberArk Commons](https://discuss.cyberarkcommons.org/).
