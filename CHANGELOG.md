# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed
- Default to Balena, use Docker when the environment variable `USE_DOCKER` is set.
- Change format of containers to an object, instead of an array, to allow labels to be read.

### Fixed
- Throw the error instead of returning them if an update fails.
- Before updating, set update status to idle.
