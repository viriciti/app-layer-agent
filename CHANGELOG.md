# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Added
- Log whether MQTT connection is secure.
- Log whether Docker authentication is enabled.

## 1.21.2
### Changed
- Disable automatic creation of volume by default (can be enabled with `features.appVolume`).

## 1.21.1
### Fixed
- Fix Dockerfile from not being able to be built by itself.

## 1.21.0
### Added
- Each application that is installed is given their own `/data` folder which they can use to persist data.  
  These volumes are not controlled, cannot be ovewritten by App Layer Control and are never cleaned up.  
  It is up to you to manage the volume and clean it up manually if you deem it necessary.
- Create a shared volume between the containers.  
  **Note**: Every container is given `rw` rights, thus any container can overwrite files not created by them.

### Changed
- Default to Balena, use Docker when the environment variable `USE_DOCKER` is set.
- Change format of containers to an object, instead of an array, to allow labels to be read.

### Fixed
- Throw the error instead of returning them if an update fails.
- Before updating, set update status to idle.
