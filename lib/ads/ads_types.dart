enum AdType {
  banner,
  interstitial,
  directInterstitial,
  rewarded,
  native,
  appOpen,
}

enum AdState { idle, loading, loaded, showing, failed }

/// Remote Config default key names (customizable via provider)
class AdRemoteKeys {
  static const String banner = 'isBannerShow';
  static const String interstitial = 'isIntersitialShow';
  static const String native = 'isNativeShow';
  static const String appOpen = 'isAppopenShow';
  static const String rewarded = 'rewardedEnabled';
  static const String adsEnabled = 'ads_enabled';
  static const String adsCount = 'adsCount';
  static const String directInterstitial = 'isSplashIntersitialShow';
}
