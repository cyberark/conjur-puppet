# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- We now encode the variable id before retrieving it from Conjur v5. 
  Spaces are encoded into "%20" and slashes into "%2F"
  ([cyberark/conjur-puppet#71](https://github.com/cyberark/conjur-puppet/pull/71))

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

[Unreleased]: https://github.com/cyberark/conjur-puppet/compare/v2.0.2...HEAD
[2.0.2]: https://github.com/cyberark/conjur-puppet/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/cyberark/conjur-puppet/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/cyberark/conjur-puppet/compare/v1.2.0...v2.0.0
[1.2.0]: https://github.com/cyberark/conjur-puppet/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/cyberark/conjur-puppet/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/cyberark/conjur-puppet/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/cyberark/conjur-puppet/compare/v0.0.4...v1.0.0
[0.0.4]: https://github.com/cyberark/conjur-puppet/compare/v0.0.2...v0.0.4
