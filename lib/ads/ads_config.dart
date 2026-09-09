import 'ads_platform.dart';
import 'ads_types.dart';

class AdsConfig {
  /// Ad Unit IDs — ALL OPTIONAL. Pass only what you have.
  final PlatformAdIds? directInterstitialIds;
  final bool directInterstitialEnabled;
  final PlatformAdIds? bannerIds;
  final PlatformAdIds? interstitialIds;
  final PlatformAdIds? nativeIds;
  final PlatformAdIds? appOpenIds;
  final PlatformAdIds? rewardedIds;

  /// Enable/disable flags per ad type
  final bool bannerEnabled;
  final bool interstitialEnabled;
  final bool nativeEnabled;
  final bool appOpenEnabled;
  final bool rewardedEnabled;

  /// Global kill switch
  final bool adsEnabled;

  /// Interstitial frequency: show after N screen visits
  final int interstitialAfter;

  /// Retry settings
  final int maxRetryAttempts;
  final Duration retryBaseDelay;
  final bool preloadEnabled;

  /// Connectivity settings
  final Duration connectivityRecheckInterval;

  const AdsConfig({
    this.directInterstitialIds,
    this.directInterstitialEnabled = true,
    this.bannerIds,
    this.interstitialIds,
    this.nativeIds,
    this.appOpenIds,
    this.rewardedIds,
    this.bannerEnabled = true,
    this.interstitialEnabled = true,
    this.nativeEnabled = false,
    this.appOpenEnabled = true,
    this.rewardedEnabled = true,
    this.adsEnabled = true,
    this.interstitialAfter = 2,
    this.maxRetryAttempts = 2,
    this.retryBaseDelay = const Duration(seconds: 10),
    this.preloadEnabled = true,
    this.connectivityRecheckInterval = const Duration(minutes: 3),
  });

  // ══════════════════════════════════════════════
  //  SMART AVAILABILITY CHECKS
  // ══════════════════════════════════════════════

  /// Returns the set of ad types that have valid keys AND are enabled
  Set<AdType> get availableAdTypes => {
    if (isBannerAvailable) AdType.banner,
    if (isInterstitialAvailable) AdType.interstitial,
    if (isNativeAvailable) AdType.native,
    if (isAppOpenAvailable) AdType.appOpen,
    if (isRewardedAvailable) AdType.rewarded,
    if (isDirectInterstitialAvailable) AdType.directInterstitial,
  };
  bool get isDirectInterstitialAvailable =>
      adsEnabled &&
      directInterstitialEnabled &&
      directInterstitialIds != null &&
      !directInterstitialIds!.isEmpty;
  bool get isBannerAvailable =>
      adsEnabled && bannerEnabled && bannerIds != null && !bannerIds!.isEmpty;

  bool get isInterstitialAvailable =>
      adsEnabled &&
      interstitialEnabled &&
      interstitialIds != null &&
      !interstitialIds!.isEmpty &&
      interstitialAfter > 0;

  bool get isNativeAvailable =>
      adsEnabled && nativeEnabled && nativeIds != null && !nativeIds!.isEmpty;

  bool get isAppOpenAvailable =>
      adsEnabled &&
      appOpenEnabled &&
      appOpenIds != null &&
      !appOpenIds!.isEmpty;

  bool get isRewardedAvailable =>
      adsEnabled &&
      rewardedEnabled &&
      rewardedIds != null &&
      !rewardedIds!.isEmpty;

  bool hasAdType(AdType type) => availableAdTypes.contains(type);

  /// Get the current platform ad ID for a type (null if not available)
  String? adIdFor(AdType type) => switch (type) {
    AdType.banner => bannerIds?.current,
    AdType.interstitial => interstitialIds?.current,
    AdType.native => nativeIds?.current,
    AdType.appOpen => appOpenIds?.current,
    AdType.rewarded => rewardedIds?.current,
    AdType.directInterstitial => directInterstitialIds?.current,
  };

  AdsConfig copyWith({
    PlatformAdIds? bannerIds,
    PlatformAdIds? interstitialIds,
    PlatformAdIds? nativeIds,
    PlatformAdIds? appOpenIds,
    PlatformAdIds? rewardedIds,
    PlatformAdIds? directInterstitialIds,
    bool? bannerEnabled,
    bool? interstitialEnabled,
    bool? nativeEnabled,
    bool? appOpenEnabled,
    bool? rewardedEnabled,
    bool? adsEnabled,
    int? interstitialAfter,
    int? maxRetryAttempts,
    Duration? retryBaseDelay,
    bool? preloadEnabled,
  }) {
    return AdsConfig(
      bannerIds: bannerIds ?? this.bannerIds,
      interstitialIds: interstitialIds ?? this.interstitialIds,
      nativeIds: nativeIds ?? this.nativeIds,
      appOpenIds: appOpenIds ?? this.appOpenIds,
      rewardedIds: rewardedIds ?? this.rewardedIds,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      interstitialEnabled: interstitialEnabled ?? this.interstitialEnabled,
      nativeEnabled: nativeEnabled ?? this.nativeEnabled,
      appOpenEnabled: appOpenEnabled ?? this.appOpenEnabled,
      rewardedEnabled: rewardedEnabled ?? this.rewardedEnabled,
      adsEnabled: adsEnabled ?? this.adsEnabled,
      interstitialAfter: interstitialAfter ?? this.interstitialAfter,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryBaseDelay: retryBaseDelay ?? this.retryBaseDelay,
      preloadEnabled: preloadEnabled ?? this.preloadEnabled,
      directInterstitialIds:
          directInterstitialIds ?? this.directInterstitialIds,
    );
  }

  @override
  String toString() =>
      'AdsConfig(available: $availableAdTypes, '
      'enabled: $adsEnabled, interstitialAfter: $interstitialAfter)';
}
