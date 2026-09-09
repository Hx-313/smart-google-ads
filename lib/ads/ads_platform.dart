import 'package:flutter/foundation.dart';

/// Ad unit IDs for Android and iOS, with optional debug/test IDs.
///
/// In debug builds the package first selects [debugAndroid] or [debugIos] for
/// the current platform, then falls back to the shared [debug] value for
/// backwards compatibility. In release/profile builds it selects the ID for
/// the current platform. Unsupported platforms resolve to an empty string and
/// therefore do not create an ad handler.
class PlatformAdIds {
  final String android;
  final String ios;
  final String debug;
  final String debugAndroid;
  final String debugIos;

  const PlatformAdIds({
    this.android = '',
    this.ios = '',
    this.debug = '',
    this.debugAndroid = '',
    this.debugIos = '',
  });

  String get current {
    if (kDebugMode) {
      final platformDebug = switch (defaultTargetPlatform) {
        TargetPlatform.android => debugAndroid,
        TargetPlatform.iOS => debugIos,
        _ => '',
      };
      if (platformDebug.isNotEmpty) return platformDebug;
      if (debug.isNotEmpty) return debug;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => '',
    };
  }

  /// Returns true when no ID was supplied, including no debug IDs.
  bool get isEmpty =>
      android.isEmpty &&
      ios.isEmpty &&
      debug.isEmpty &&
      debugAndroid.isEmpty &&
      debugIos.isEmpty;

  /// Returns true when this value has an ID usable by the current build.
  bool get isAvailable => current.isNotEmpty;
}

/// Platform-specific Remote Config keys.
///
/// This type is kept for consumers that use platform-specific configuration
/// outside the built-in ads provider.
class PlatformRCKeys {
  final String android;
  final String ios;

  const PlatformRCKeys({required this.android, required this.ios});

  String get current => switch (defaultTargetPlatform) {
    TargetPlatform.android => android,
    TargetPlatform.iOS => ios,
    _ => '',
  };
}
