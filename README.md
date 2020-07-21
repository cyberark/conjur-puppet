# conjur

[![Version](https://img.shields.io/puppetforge/v/cyberark/conjur.svg)](https://forge.puppet.com/cyberark/conjur)

#### Table of Contents

- [Description](#description)
- [Setup](#setup)
  * [Setup requirements](#setup-requirements)
  * [Using `conjur-puppet` with Conjur OSS](#using-conjur-puppet-with-conjur-oss)
  * [Conjur module basics](#conjur-module-basics)
    + [Sensitive data type](#sensitive-data-type)
- [Usage](#usage)
  - [Creating a Conjur host and providing its identity and API key](#conjur-host-identity-with-api-key)
  - [Using Conjur host factory](#conjur-host-factory)
  - [Using pre-established host identities (**Conjur Enterprise v4 only**)](#pre-established-host-identity-conjur-enterprise-v4-only)
- [Reference](#reference)
- [Limitations](#limitations)
- [Contributing](#contributing)
- [Support](#support)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>


## Description

This is the official Puppet module for [Conjur](https://www.conjur.org), a robust
identity and access management platform. This module simplifies the operations of
establishing Conjur host identity and allows authorized Puppet nodes to fetch
secrets from Conjur.

## Setup

### Setup requirements

This module requires that you have:
- Puppet v5 _or equivalent EE version_
- Puppet v5 agent on the nodes
- Conjur endpoint available to both the Puppet server and the Puppet nodes using this
  module. Supported versions:
  - Conjur OSS v1+
  - DAP v10+
  - Conjur Enterprise v4.9+

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

This module provides a `conjur::secret` function that can be used to retrieve secrets
from Conjur. Given a Conjur variable identifier, `conjur::secret` uses the node’s
Conjur identity to resolve and return the variable’s value.

```puppet
$dbpass = conjur::secret('production/postgres/password')
```

Hiera attributes can also be used to inform which secret should be fetched,
depending on the node running the Conjur module. For example, if `hiera('domain')`
returns `app1.example.com` and a Conjur variable named `domains/app1.example.com/ssl-cert`
exists, the SSL certificate can be retrieved and written to a file like so:

```puppet
file { '/abslute/path/to/cert.pem':
  ensure    => file,
  content   => conjur::secret("domains/%{hiera('domain')}/ssl-cert"),
  show_diff => false # only required for Puppet < 4.6
  # diff will automatically get redacted in 4.6 if content is Sensitive
}
```

To install a specific version of this module (e.g. `v1.2.3`), run the following
command on the Puppet server:
```
puppet module install cyberark-conjur --version 1.2.3
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
$dbpass = conjur::secret('production/postgres/password')

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
for any applications, machines, or processes that will need to interact with Conjur.

In this module, we provide multiple ways to establish Conjur application identity for
Puppet nodes, including:
- [Creating a Conjur host and providing its identity and API key](#conjur-host-identity-with-api-key)
- [Using Conjur host factory](#conjur-host-factory)
- [Using pre-established host identities (**Conjur Enterprise v4 only**)](#pre-established-host-identity-conjur-enterprise-v4-only)

Please note that before getting started configuring your Puppet environment, you'll need
to load policy in Conjur to define the application identities that you will be using to
authenticate to Conjur. To learn more about
[creating hosts](https://docs.conjur.org/Latest/en/Content/Operations/Policy/statement-ref-host.htm)
or [using host factories](https://docs.conjur.org/Latest/en/Content/Operations/Services/host_factory.html),
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
- `host_factory_token`: The Conjur host factory token, provided as a string or using the
  [Puppet file resource type](https://puppet.com/docs/puppet/latest/types/file.html).
- `cert_file`: The file path for the PEM-encoded x509 CA certificate chain for the DAP
  instance you are connecting to. This file is read from the **Puppet server**. This
  configuration parameter overrides `ssl_certificate`.
- `ssl_certificate`: The PEM-encoded x509 CA certificate chain for the DAP instance you
  are connecting to, provided as a string or using the
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
- `version`: Conjur API version, defaults to 5.

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
its host identity and its API key to your manifest like this:
```puppet
class { 'conjur':
  appliance_url   => 'https://conjur.mycompany.com/',
  account         => 'myorg',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate => file('/absolute/path/to/conjur-ca.pem')
}
```

##### Using Hiera

You can also add the Conjur identity configuration to Hiera, which provides the Conjur
identity information to the Puppet **server**:

```yaml
---
lookup_options:
  '^conjur::authn_api_key':
    convert_to: 'Sensitive'

conjur::appliance_url: 'https://conjur.mycompany.com/'
conjur::account: 'myorg'
conjur::authn_login: 'host/redis001'
conjur::authn_api_key: 'f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'
# conjur::cert_file: '/absolute/path/to/conjur-ca.pem' # Read from the Puppet server
conjur::ssl_certificate: |
  -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
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
         the file permissions for these files is set to `600` so as to
         disallow any access to these files by unauthorized (non-root) users
         on a Linux Puppet agent node.**_

The Conjur Puppet Module will automatically check for these files on your node and use them if they
are available.
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
| Account | REG_SZ | Conjur account specified during Conjur setup. |
| ApplianceUrl | REG_SZ | Conjur API endpoint. |
| CertFile | REG_SZ | File path to public Conjur SSL cert. This file is read from the **Puppet agent**. Takes precedence over `SslCertificate`. |
| SslCertificate | REG_SZ | Public Conjur SSL cert. Overwritten by the contents read from `CertFile` when it is present. |
| Version | REG_DWORD | Conjur API version. Defaults to `5`. |

These may be set using Powershell (**use either `SslCertificate` _or_ `CertFile` but not both**):

```powershell
> reg ADD HKLM\Software\CyberArk\Conjur /v ApplianceUrl /t REG_SZ /d https://conjur.mycompany.com
> reg ADD HKLM\Software\CyberArk\Conjur /v Version /t REG_DWORD /d 5
> reg ADD HKLM\Software\CyberArk\Conjur /v Account /t REG_SZ /d myorg
> reg ADD HKLM\Software\CyberArk\Conjur /v SslCertificate /t REG_SZ /d "-----BEGIN CERTIFICATE-----..."
> reg ADD HKLM\Software\CyberArk\Conjur /v CertFile /t REG_SZ /d "C:\Absolute\Path\To\SslCertificate"
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
"CertFile"="C:\Absolute\Path\To\SslCertificate"
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

#### Conjur host factory

Conjur [Host Factories](https://docs.conjur.org/Latest/en/Content/Operations/Services/host_factory.html)
are another method for creating new host identities in Conjur, and it ensures
new hosts are created in an existing Conjur policy
[layer](https://docs.conjur.org/Latest/en/Content/Operations/Policy/statement-ref-layer.htm)
that is already entitled to access some secret values in Conjur. That is, when
using host factory, nodes inherit the permissions of the layer for which the Host Factory
token was generated.

The Conjur Puppet module is provided with a host factory token which will only be used on
the initial Puppet run to establish identity. In the initial Puppet run, the Conjur identity
is created by the Puppet server and then stored on the agent's host. Subsequent runs will
use the created identity for Conjur authentication on the agent side (at the time of collecting facts), and
the agent will only provide the Puppet server with a temporary token to fetch secrets from Conjur.

##### Updating the Puppet manifest

To use a Host Factory token with this module, set variables `authn_login` and
`host_factory_token` in the Puppet manifest. Do not set the variable `authn_api_key`
when using `host_factory_token` as it is not required. `authn_login` should have a
`host/` prefix and the part after the slash will be used as the node’s name in Conjur.

```puppet
class { 'conjur':
  appliance_url      => 'https://conjur.mycompany.com/',
  account            => 'myorg',
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx'),
  cert_file          => '/absolute/path/to/conjur.pem' # Read from the Puppet server
}
```

Conjur will automatically add the annotation `puppet: true` to the Conjur host
identities of all nodes using this Puppet module to bootstrap identity with
`host_factory_token`.

##### Using Hiera

Rather than storing the host factory token in the manifest, Puppet server can also be
configured to retrieve the host factory token from Hiera when communicating with its agents:

```yaml
---
lookup_options:
  '^conjur::host_factory_token':
    convert_to: 'Sensitive'

conjur::appliance_url: 'https://conjur.mycompany.com/'
conjur::account: 'myorg'
conjur::authn_login: 'host/redis001'
conjur::host_factory_token: '3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx'
# conjur::cert_file: '/absolute/path/to/conjur-ca.pem' # Read from the Puppet Server
conjur::ssl_certificate: |
  -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
```

##### Pre-established host identity (Conjur Enterprise v4 only)

**When using Conjur Enterprise v4 only**, you can use
[conjurize](https://developer.conjur.net/tutorials/authorization/hosts.html)
or a similar method to establish host identity before running Puppet to configure.
This way Puppet master only ever handles a temporary access token instead of real,
permanent Conjur credentials of the hosts it manages.

If a host is so pre-configured, the settings and credentials are automatically
obtained and used. In this case, all that is needed to use `conjur::secret` is a simple

```puppet
include conjur
```

## Reference

### Classes

#### Public Classes

* [`conjur`](#conjur-class): Establishes a host identity on the node.

### Functions

#### Public Functions

* [`conjur::secret`](#conjursecret): Retrieve a secret using the host identity.

### Facts

#### Private facts

* [`conjur`](#conjur-fact): Reports current node configuration and identity.

### `conjur` class

This class establishes Conjur host identity on the node so that secrets can be
fetched from Conjur. The identity and Conjur endpoint configuration can be
pre-configured on a host using `/etc/conjur.conf` and `/etc/conjur.identity` on Linux, or
Windows Registry and Window Credentials Manager on Windows, (by way of
[`conjur` fact](#conjur-fact)) or provided as parameters. The identity can also be
bootstrapped using the host factory token parameter.

When this class is instantiated in such a way that it has access to an API key (`authn_api_key`),
the identity is persisted on the agent using the same OS specific machine identity
artifacts as mentioned in the pre-configured case above. This happens when the host
factory parameter is used since a host's API key is retrieved as part of that flow. _Note
that when this persistence occurs the `cert_file` parameter is always converted to the
`ssl_certificate` equivalent for the artifact._

#### Note

Several parameters (ie. API keys) are of `Sensitive` data type.
To pass a normal string, you need to wrap it using `Sensitive("example")`.

#### Parameters

##### `account`
Conjur account authority name. Optional for v4, required for v5.

##### `appliance_url`
A Conjur endpoint (with trailing `/api/` for v4).

##### `authn_login`
User username or host name (prefixed with `host/`).

##### `authn_api_key`
API key for a user or host. Must be `Sensitive` if supported.

##### `cert_file`
File path to X509 certificate of the root CA of Conjur, PEM formatted. This file is read
from the **Puppet server**. Takes precedence over `ssl_certificate`.

##### `ssl_certificate`
Content of the X509 certificate of the root CA of Conjur, PEM formatted.
When using Puppet's `file` function, the path to the cert must be absolute.
Overwritten by the contents read from `cert_file` when it is present.

##### `host_factory_token`
You can use a host factory token to obtain a host identity. Must be `Sensitive`.
Simply use this parameter to set it. The host record will be created in Conjur.

##### `authn_token`
Raw (unencoded) Conjur token. This is usually only useful for testing.
Must be `Sensitive`.

##### `version`
Conjur API version. Defaults to 5. Set to 4 if you're using Conjur Enterprise 4.x.

#### Examples

```puppet
# use a pre-existing Conjur configuration host identity
include conjur

# using an host factory token
class { 'conjur':
  appliance_url      => 'https://conjur.mycompany.com/',
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate    => file('/absolute/path/to/conjur-ca.pem'),
  version            => 5
}

# same, but /etc/conjur.conf and certificate are already on a host
# (eg. baked into a base image)
class { 'conjur':
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3')
}

# using an API key
class { 'conjur':
  account         => 'mycompany',
  appliance_url   => 'https://conjur.mycompany.com/',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate => file('/abslute/path/to/conjur-ca.pem'),
  version         => 5
}

# same, but 'cert_file' is used instead of 'ssl_certificate'
class { 'conjur':
  account         => 'mycompany',
  appliance_url   => 'https://conjur.mycompany.com/',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  cert_file       => '/absolute/path/to/conjur-ca.pem', # Read from the Puppet server
  version         => 5
}
```

### `conjur::secret`

This function uses the node’s Conjur host identity to authenticate with Conjur
and retrieve a secret that the node is authorized to fetch. The output of this
function is a string that contains the value of the variable parameter. If the
secret cannot be fetched an error is thrown.

The returned value is `Sensitive` data type.

#### Parameters

##### `variable`
The identifier of a Conjur variable to retrieve.

#### Example

```puppet
dbpass = conjur::secret('production/postgres/password')
```

### `conjur` fact

This internal, structured fact is used to inform the master of the current node
Conjur configuration and identity.

Pre-establishing configuration and identity is the recommended way of using this
module, for example by pre-baking the configuration into a base image and bootstrapping
the identity using an orchestration solution (see [Usage](#usage) section). If
used this way, the Puppet master only has access to the 8-minute bearer token
issued for the host and never handles long-term credentials.

- If the node is preconfigured with Conjur settings, they're reported in this
  fact and they're used as defaults by the `::conjur` class.
- If additionally the host has a Conjur identity pre-configured (ie. API key in
  `/etc/conjur.identity` on Linux or Windows Credentials Manager on Windows), the node
  uses that to authenticate to Conjur. It gets back the standard temporary Conjur token
  which is encrypted with the Puppet master's public TLS key and reported in this fact. This
  ensures only the master (with the corresponding private key) can decrypt and use it.

## Limitations

See [metadata.json](metadata.json) for supported platforms

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
