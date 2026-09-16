## 0.2.0

* Documented Android GMA Next-Gen builds and mediation constraints.
* Gated Mobile Ads initialization on the UMP ad-request decision.
* Updated adaptive banners and app-open lifecycle handling to current plugin
  APIs.
* Made omitted consent environment-aware: debug skips UMP for test ads and
  release enforces UMP; explicit consent values still override the default.
* Consolidated Remote Config setup under `AdsRemoteConfigOptions`.
* Replaced the shimmer runtime dependency with a static Flutter placeholder.

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
