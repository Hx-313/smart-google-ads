import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'ads_config.dart';
import 'ads_types.dart';
import 'd_print.dart';

// ══════════════════════════════════════════════════════════════
//  ABSTRACT PROVIDER
// ══════════════════════════════════════════════════════════════

abstract class AdsKeyProvider {
  Future<AdsConfig> getConfig();
}

// ══════════════════════════════════════════════════════════════
//  1. DIRECT PROVIDER — No Remote Config needed
// ══════════════════════════════════════════════════════════════

class DirectAdsKeyProvider implements AdsKeyProvider {
  final AdsConfig _config;
  const DirectAdsKeyProvider(this._config);

  @override
  Future<AdsConfig> getConfig() async => _config;
}

// ══════════════════════════════════════════════════════════════
//  2. REMOTE CONFIG PROVIDER
// ══════════════════════════════════════════════════════════════

class RemoteConfigAdsKeyProvider implements AdsKeyProvider {
  /// Fallback config used if remote fetch fails
  final AdsConfig fallback;

  /// Custom remote config key names (override defaults)
  final Map<String, String>? customKeys;

  /// Optional extra keys to fetch (e.g., your aiApiKey)
  final void Function(FirebaseRemoteConfig rc)? onConfigFetched;

  RemoteConfigAdsKeyProvider({
    required this.fallback,
    this.customKeys,
    this.onConfigFetched,
  });

  @override
  Future<AdsConfig> getConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;

      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 6),
        ),
      );

      // Set defaults from fallback so keys always resolve
      await rc.setDefaults({
        _key(AdRemoteKeys.banner): fallback.bannerEnabled,
        _key(AdRemoteKeys.interstitial): fallback.interstitialEnabled,
        _key(AdRemoteKeys.native): fallback.nativeEnabled,
        _key(AdRemoteKeys.appOpen): fallback.appOpenEnabled,
        _key(AdRemoteKeys.rewarded): fallback.rewardedEnabled,
        _key(AdRemoteKeys.adsEnabled): fallback.adsEnabled,
        _key(AdRemoteKeys.adsCount): fallback.interstitialAfter,
      });

      await rc.fetchAndActivate();

      // Let the caller read any extra keys they need
      onConfigFetched?.call(rc);

      final config = fallback.copyWith(
        bannerEnabled: rc.getBool(_key(AdRemoteKeys.banner)),
        interstitialEnabled: rc.getBool(_key(AdRemoteKeys.interstitial)),
        nativeEnabled: rc.getBool(_key(AdRemoteKeys.native)),
        appOpenEnabled: rc.getBool(_key(AdRemoteKeys.appOpen)),
        rewardedEnabled: rc.getBool(_key(AdRemoteKeys.rewarded)),

        // 🟢 FIXED: If 'ads_enabled' is missing in Remote Config, default to TRUE
        adsEnabled: _getRemoteBool(rc, _key(AdRemoteKeys.adsEnabled), true),

        interstitialAfter: rc.getInt(_key(AdRemoteKeys.adsCount)),
      );

      dPrint('🔥 RemoteConfig: $config');
      return config;
    } catch (e) {
      dPrint('❌ RemoteConfig failed: $e — using fallback');
      return fallback;
    }
  }

  /// Helper: Checks if the key exists in Firebase. If not, returns the defaultValue.
  bool _getRemoteBool(FirebaseRemoteConfig rc, String key, bool defaultValue) {
    final value = rc.getValue(key);
    // If it was successfully fetched from the cloud, use the cloud value
    if (value.source == ValueSource.valueRemote) {
      return value.asBool();
    }
    // Otherwise (missing from cloud), force the default value
    return defaultValue;
  }

  String _key(String defaultKey) => customKeys?[defaultKey] ?? defaultKey;
}
