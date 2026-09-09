import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'ads_key_provider.dart';
import 'ads_privacy.dart';
import 'ads_platform.dart';
import 'ads_service.dart';
import 'ads_types.dart';
import 'd_print.dart';

/// All ad unit IDs used by [AdsBootstrap].
///
/// An ad type is optional. If its value is omitted, empty, or has no ID for
/// the current platform, that ad type is simply unavailable. This lets an app
/// ship a banner-only or rewarded-only configuration without special cases.
///
/// Use [PlatformAdIds.debugAndroid] and [PlatformAdIds.debugIos] for Google's
/// platform-specific test IDs when developing. [PlatformAdIds.debug] remains a
/// shared fallback for older configurations. Never use production IDs while
/// testing.
class AdsAdUnitIds {
  final PlatformAdIds? banner;
  final PlatformAdIds? interstitial;
  final PlatformAdIds? rewarded;
  final PlatformAdIds? native;
  final PlatformAdIds? appOpen;
  final PlatformAdIds? directInterstitial;

  const AdsAdUnitIds({
    this.banner,
    this.interstitial,
    this.rewarded,
    this.native,
    this.appOpen,
    this.directInterstitial,
  });

  /// True when no ad unit ID was supplied at all.
  bool get isEmpty => [
    banner,
    interstitial,
    rewarded,
    native,
    appOpen,
    directInterstitial,
  ].every((ids) => ids == null || ids.isEmpty);

  AdsConfig toConfig({
    bool? bannerEnabled,
    bool? interstitialEnabled,
    bool? nativeEnabled,
    bool? appOpenEnabled,
    bool? rewardedEnabled,
    bool? directInterstitialEnabled,
    bool adsEnabled = true,
    int interstitialAfter = 3,
    int maxRetryAttempts = 2,
    Duration retryBaseDelay = const Duration(seconds: 10),
    bool preloadEnabled = true,
    Duration connectivityRecheckInterval = const Duration(minutes: 3),
  }) {
    return AdsConfig(
      bannerIds: banner,
      interstitialIds: interstitial,
      rewardedIds: rewarded,
      nativeIds: native,
      appOpenIds: appOpen,
      directInterstitialIds: directInterstitial,
      bannerEnabled: bannerEnabled ?? banner?.isAvailable == true,
      interstitialEnabled:
          interstitialEnabled ?? interstitial?.isAvailable == true,
      // Native ads are opt-in because they normally need a custom layout.
      nativeEnabled: nativeEnabled ?? false,
      appOpenEnabled: appOpenEnabled ?? appOpen?.isAvailable == true,
      rewardedEnabled: rewardedEnabled ?? rewarded?.isAvailable == true,
      directInterstitialEnabled:
          directInterstitialEnabled ?? directInterstitial?.isAvailable == true,
      adsEnabled: adsEnabled,
      interstitialAfter: interstitialAfter,
      maxRetryAttempts: maxRetryAttempts,
      retryBaseDelay: retryBaseDelay,
      preloadEnabled: preloadEnabled,
      connectivityRecheckInterval: connectivityRecheckInterval,
    );
  }
}

/// Controls how [AdsBootstrap] obtains feature flags.
///
/// Firebase itself must be initialized by the host app before the package is
/// initialized. The package owns Remote Config settings, defaults, fetching,
/// activation, and merging those flags with the supplied IDs.
class AdsRemoteConfigOptions {
  /// Set to false to use the supplied IDs and local defaults only.
  final bool enabled;

  /// Maps the package's standard keys to the keys in the host app's project.
  /// Unspecified keys use [AdRemoteKeys]' standard names.
  final Map<String, String> keys;

  final Duration fetchTimeout;
  final Duration minimumFetchInterval;

  /// Called after a successful fetch and activation.
  final void Function(FirebaseRemoteConfig remoteConfig)? onFetched;

  const AdsRemoteConfigOptions({
    this.enabled = true,
    this.keys = const {},
    this.fetchTimeout = const Duration(seconds: 10),
    this.minimumFetchInterval = const Duration(hours: 6),
    this.onFetched,
  });

  const AdsRemoteConfigOptions.disabled()
    : enabled = false,
      keys = const {},
      fetchTimeout = const Duration(seconds: 10),
      minimumFetchInterval = const Duration(hours: 6),
      onFetched = null;
}

/// Package-owned entry point for initializing the complete ads stack.
///
/// The host app only needs to provide [adUnitIds], whether Remote Config is
/// enabled, and an optional premium-user callback. Mobile Ads initialization,
/// config fallback, handler creation, preload, and lifecycle observation are
/// handled by the package. Consent and request restrictions are opt-in through
/// [AdsConsentOptions] and [AdsPolicyOptions], respectively.
class AdsBootstrap {
  AdsBootstrap._();

  /// Whether the package has completed initialization.
  static bool get isInitialized => AdsService.isInitialized;

  static AdsConsentManager? _consentManager;

  /// The UMP manager used during bootstrap, if consent integration was
  /// explicitly enabled. Null means the package is running in legacy mode.
  static AdsConsentManager? get consentManager => _consentManager;

  /// Whether Google requires a visible privacy-options entry point.
  static Future<bool> isPrivacyOptionsRequired() async {
    return await _consentManager?.isPrivacyOptionsRequired() ?? false;
  }

  /// Shows Google's privacy-options form and refreshes the ads gate.
  ///
  /// Returns the post-form value of [AdsService.canRequestAds]. It returns
  /// false when consent integration was not enabled or initialization has not
  /// completed.
  static Future<bool> showPrivacyOptions() async {
    final manager = _consentManager;
    if (manager == null) return false;

    await manager.showPrivacyOptions();
    if (!AdsService.isInitialized) return manager.canRequestAds();

    await AdsService.instance.refreshConsent();
    return AdsService.instance.canRequestAds;
  }

  /// Initialize the package once.
  ///
  /// Calling this method more than once is safe; subsequent calls are ignored
  /// by [AdsService]. Initialization errors are logged and do not crash the
  /// host app, because advertising should never prevent the app from opening.
  static Future<AdsService> init({
    required AdsAdUnitIds adUnitIds,
    bool useRemoteConfig = false,
    AdsRemoteConfigOptions? remoteConfig,
    int interstitialAfter = 3,
    bool Function()? isProUser,
    void Function(FirebaseRemoteConfig remoteConfig)? onRemoteConfigFetched,
    Map<String, String>? customRCKeys,
    AdsConsentOptions? consent,
    AdsPolicyOptions? policy,
    bool? bannerEnabled,
    bool? interstitialEnabled,
    bool? nativeEnabled,
    bool? appOpenEnabled,
    bool? rewardedEnabled,
    bool? directInterstitialEnabled,
    bool adsEnabled = true,
    int maxRetryAttempts = 2,
    Duration retryBaseDelay = const Duration(seconds: 10),
    bool preloadEnabled = true,
    Duration connectivityRecheckInterval = const Duration(minutes: 3),
  }) async {
    if (AdsService.isInitialized) {
      dPrint('🔁 AdsBootstrap: already initialized, skipping');
      return AdsService.instance;
    }

    final options =
        remoteConfig ??
        AdsRemoteConfigOptions(
          enabled: useRemoteConfig,
          keys: customRCKeys ?? const {},
          onFetched: onRemoteConfigFetched,
        );

    _consentManager = null;
    AdsConsentManager? consentManager;
    if (consent != null) {
      consentManager = AdsConsentManager();
      _consentManager = consentManager;
      final canRequestAds = await consentManager.requestConsent(consent);
      dPrint('🛡️ AdsBootstrap: consent gate allows ads = $canRequestAds');
    }

    if (policy != null) {
      try {
        await MobileAds.instance.updateRequestConfiguration(
          policy.toRequestConfiguration(),
        );
      } catch (error) {
        // Restriction configuration must not make the host app fail to open.
        // The host can observe this in its own logs and should verify native
        // setup if it occurs.
        dPrint('⚠️ AdsBootstrap: request policy could not be applied: $error');
      }
    }

    final config = adUnitIds.toConfig(
      bannerEnabled: bannerEnabled,
      interstitialEnabled: interstitialEnabled,
      nativeEnabled: nativeEnabled,
      appOpenEnabled: appOpenEnabled,
      rewardedEnabled: rewardedEnabled,
      directInterstitialEnabled: directInterstitialEnabled,
      adsEnabled: adsEnabled,
      interstitialAfter: interstitialAfter,
      maxRetryAttempts: maxRetryAttempts,
      retryBaseDelay: retryBaseDelay,
      preloadEnabled: preloadEnabled,
      connectivityRecheckInterval: connectivityRecheckInterval,
    );

    dPrint('🚀 AdsBootstrap: starting with ${config.availableAdTypes}');

    final AdsKeyProvider provider;
    if (options.enabled) {
      provider = RemoteConfigAdsKeyProvider(
        fallback: config,
        customKeys: options.keys,
        onConfigFetched: options.onFetched,
        fetchTimeout: options.fetchTimeout,
        minimumFetchInterval: options.minimumFetchInterval,
      );
      dPrint('🔥 AdsBootstrap: Remote Config enabled');
    } else {
      provider = DirectAdsKeyProvider(config);
      dPrint('📦 AdsBootstrap: using supplied IDs without Remote Config');
    }

    try {
      final service = await AdsService.initialize(
        keyProvider: provider,
        isProUser: isProUser,
        consentChecker: consentManager?.canRequestAds,
      );
      dPrint('✅ AdsBootstrap: initialization complete');
      service.dPrintDebug();
      return service;
    } catch (error, stackTrace) {
      dPrint('❌ AdsBootstrap: initialization failed: $error');
      dPrint('$stackTrace');
      // The service's safe pre-init getters keep the host app usable.
      return AdsService.instance;
    }
  }
}
