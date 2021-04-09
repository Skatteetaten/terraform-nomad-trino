# Changelog

## [UNRELEASED 0.4.0]

### Changed
- Prestosql changed name to Trino. This repo changed with it. #106
- Updated all references to Presto #106
- Bumped version Postgres -> 0.4.0 (trino_standalone) #111
- Bumped version Minio -> 0.4.0 (trino_standalone) #111
- Bumped version Hive -> 0.4.0 (trino_standalone) #111

### Added
- Trino consul connect plugin source and build
- Using Trino docker image with tag 354 #106
- Support for Postrgres connector #105

### Fixed
- `make clean` will clean terraform state

## [0.3.2]

### Changed
- Changed from an HTTP check to a script check for `presto-minio-availability` #100
- Bumped version of Hive 0.3.1 -> 0.4.0 [no issue]
- Bumped version of Vagrantbox 0.7.1 -> 0.9.0 #96
- Now uses variable to set consul image [no issue]

## [0.3.1]

### Added

- Improve credentials management (vault provided credentials) #64
- Added variable `hive_config_properties` for custom hive configuration properties #90

### Changed

- hive module 0.3.0 -> 0.3.1
- Changed to anothrNick/github-tag-action to get bumped version tags. Old action is deprecated [no issue]

## [0.3.0]

### Added
- Json flatten VIEW example #65
- Added CPU as user defined variable #67
- Two target, for standalone and cluster version of trino #61
- Sidecar proxy to both examples with variables #73

### Changed
- Variables regarding credentials/secrets & updated documentation #52
- Updated box version to 0.7.x #69
- Additional information about proxies and Trino CLI #60
- Updated Verifying setup section in readme #46
- Bumped module versions in both examples #77
- Re-added healthchecks #81
- Using explicit variable definition instead of locals #82

### Fixed
- `make up` warning #57

## [0.2.0]

### Added
- Github templates for issues and PRs #43

### Changed
- Synced with template and upgraded box version #41
- Updated input and ouput sections in readme #49
- Updated modules version #47
- Updated documentation -> section intentions #53

## [0.1.0]

### Added

- Data examples & create tables #5 #4
- Documentation #3 #8
- Fixate linter version #10
- Consul Connect enabled multi node cluster #13 #14 #16 #19 #24
- Code to support successful execution of nomad trino job and tests when consul_acl_default_policy is deny #32
- Added switch for canary deployment #25
- Added random secret (in vault) for trino cluster communication #29

## Changed

- Use docker instead fo binaries #21
- size vagrant box to runner in github actions #23
- Sync origin template #28
- Bumped version minio: 0.0.2 -> 0.1.0
- Bumped version hive: 0.0.2 -> 0.1.0
- Bumped version postgres: 0.0.1 -> 0.1.0
- Consul Connect plugin optional with configurable artifact source #30

## Fixed

- ansible repeating variables #20

## [0.0.1]

### Added

- Initial draft #1
