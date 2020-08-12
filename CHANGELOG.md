# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Support for using `Deferred` secrets fetching via `conjur::secret`.
  [cyberark/conjur-puppet#13](https://github.com/cyberark/conjur-puppet/issues/13).

### Changed
- `conjur::secret` now must be used as a `Deferred` function. Method signature has
  changed as well. [cyberark/conjur-puppet#13](https://github.com/cyberark/conjur-puppet/issues/13).
- `conjur::secret` Optional parameters now use a Hash instead of positional parameters.
  [cyberark/conjur-puppet#184](https://github.com/cyberark/conjur-puppet/issues/184).

### Removed
- Support for using the Conjur Puppet module with Conjur Enterprise v4 is removed
  [cyberark/conjur-puppet#66](https://github.com/cyberark/conjur-puppet/issues/66).
- Support for using this module with Puppet v5.
  [cyberark/conjur-puppet#104](https://github.com/cyberark/conjur-puppet/issues/104).
- Support for using host factory tokens, `conjur` class, `cert_file` parameter, and using
  server-side `conjur` class to pre-populate on-agent info.
  [cyberark/conjur-puppet#104](https://github.com/cyberark/conjur-puppet/issues/104).

## [2.0.5] - 2020-07-28

### Added
- Preliminary support for Puppet 6 with Linux agents, now including Ubuntu 18.04
  and 20.04, Debian 9 and 10, and Alpine 3.9.
  [Epic cyberark/conjur-puppet#20](https://github.com/cyberark/conjur-puppet/issues/20)

### Deprecated
- Support for using the Conjur Puppet module with Conjur Enterprise v4 is now
  deprecated. Support will be removed in the next major release. The `conjurize`
  method of providing the Conjur Puppet module with its Conjur identity will
  also no longer be supported as of the next version.
- Support for using the Conjur Puppet module with [Windows Server 2008](https://support.microsoft.com/en-us/lifecycle/search?alpha=Windows%20Server%202008)
  or [Debian 7](https://wiki.debian.org/DebianWheezy) agents, since both
  operating systems have now reached end of life.

## [2.0.4] - 2020-07-20

### Added
- Preliminary support for Puppet 6 with Windows agents (Server 2012 R2,
  Server 2016, Server 2019).
  [Epic cyberark/conjur-puppet#20](https://github.com/cyberark/conjur-puppet/issues/20)
- Support for using `cert_file` in the `conjur` class or `CertFile` in Windows
  Registry on Windows as an alternative to using the existing `ssl_certificate`
  parameter.
  [cyberark/conjur-puppet#113](https://github.com/cyberark/conjur-puppet/issues/113)

### Changed
- Updated README to clarify configuration instructions.
  [cyberark/conjur-puppet#128](https://github.com/cyberark/conjur-puppet/issues/128),
  [PR cyberark/conjur-puppet#111](https://github.com/cyberark/conjur-puppet/pull/111),
  [cyberark/conjur-puppet#98](https://github.com/cyberark/conjur-puppet/issues/98),
  [cyberark/conjur-puppet#97](https://github.com/cyberark/conjur-puppet/issues/97),
  [PR cyberark/conjur-puppet#108](https://github.com/cyberark/conjur-puppet/pull/108)

### Fixed
- Module no longer returns internal server errors when decrypting tokens
  when used with Puppet 6.
  [cyberark/conjur-puppet#91](https://github.com/cyberark/conjur-puppet/issues/91)
- Module no longer relies on Puppet 6-incompatible methods for retrieving
  Puppet CA chains.
  [cyberark/conjur-puppet#44](https://github.com/cyberark/conjur-puppet/issues/44)
- Module no longer reports "identity not found" on subsequent runs for nodes
  running with HFT-created identities, and is updated with improved logging
  for Windows-based configuration and credential fetching.
  [cyberark/conjur-puppet#47](https://github.com/cyberark/conjur-puppet/issues/47)
- Module no longer fails on the first run when using Conjur Host Factory tokens
  with Hiera.
  [cyberark/conjur-puppet#112](https://github.com/cyberark/conjur-puppet/issues/112)

## [2.0.3] - 2020-05-10
### Changed
- We now encode the variable id before retrieving it from Conjur v5.
  Spaces are encoded into "%20" and slashes into "%2F".
  [cyberark/conjur-puppet#72](https://github.com/cyberark/conjur-puppet/issues/72)

## [2.0.2] - 2019-12-18
### Added
- Update support contact info in README

## [2.0.1] - 2019-07-15
### Added
- Update module manifest to include Puppet 5.x requirement

## [2.0.0] - 2019-07-08
### Removed
- Remove support for Puppet older than 4.6.

### Added
- Add support for Windows Puppet agents. See [README.md](README.md#windows) for details.

### Changed
- Change default Conjur version to 5. This a breaking change from 1.2.0.

## [1.2.0] - 2017-09-27
### Added
- Support Conjur v5 API.

## [1.1.0] - 2017-05-24
### Changed
- Cleanup and refactor of project files. No behavior change.

## [1.0.1] - 2017-03-10
### Added
- Store Conjur configuration and identity on the node, if not present.

## [1.0.0] - 2017-03-02
### Changed
- v1.0.0 is a complete revamp of the module.
- This release includes several **breaking changes**.
- See [README.md](README.md) for complete details.

## [0.0.4] - 2015-05-11
### Fixed
- fixed another instance of the same bug

## 0.0.2 - 2014-09-24
### Fixed
- fixed a bug in host identity manifest preventing usage of host factory

[Unreleased]: https://github.com/cyberark/conjur-puppet/compare/v2.0.4...HEAD
[2.0.4]: https://github.com/cyberark/conjur-puppet/compare/v2.0.3...v2.0.4
[2.0.3]: https://github.com/cyberark/conjur-puppet/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/cyberark/conjur-puppet/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/cyberark/conjur-puppet/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/cyberark/conjur-puppet/compare/v1.2.0...v2.0.0
[1.2.0]: https://github.com/cyberark/conjur-puppet/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/cyberark/conjur-puppet/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/cyberark/conjur-puppet/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/cyberark/conjur-puppet/compare/v0.0.4...v1.0.0
[0.0.4]: https://github.com/cyberark/conjur-puppet/compare/v0.0.2...v0.0.4
