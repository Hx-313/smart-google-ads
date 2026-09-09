## 0.1.1

* Added a complete local-mode example app for pub.dev users.
* Expanded setup documentation for local ad flags and interstitial frequency.
* Added missing documentation for `AdClickProvider`.
* Added platform-specific debug ad-unit ID support.

## 0.1.0

* Added the package-owned `AdsBootstrap` API.
* Added explicit platform/debug ad unit configuration.
* Added Remote Config options, defaults, fallback behavior, and all ad-type
  enable flags.
* Added ad-aware SmartDialog wrappers and usage documentation.
* Added opt-in Google UMP consent handling with a fail-closed ad-request gate.
* Added opt-in age-treatment and maximum-ad-rating request restrictions.
* Added a privacy-options helper that refreshes ad availability after a user
  changes their consent choice.
* Removed the bootstrap's dependency on host-app `.env` files.
