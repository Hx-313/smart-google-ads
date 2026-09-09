import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads_types.dart';
import 'base_ad_handler.dart';
import '../d_print.dart';

class AppOpenHandler extends BaseAdHandler {
  final String adUnitId;
  AppOpenAd? _ad;
  DateTime? _loadTime;

  static const Duration _maxCacheAge = Duration(hours: 4);

  VoidCallback? onDismissed;
  void Function(String error)? onError;

  AppOpenHandler({required this.adUnitId});

  bool get _isExpired =>
      _loadTime != null && DateTime.now().difference(_loadTime!) > _maxCacheAge;

  @override
  Future<bool> load() {
    if (state == AdState.loading) return Future.value(false);
    state = AdState.loading;
    final completer = Completer<bool>();

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadTime = DateTime.now();
          state = AdState.loaded;
          _setupCallbacks();
          completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          state = AdState.failed;
          dPrint('❌ AppOpen load failed: ${error.message}');
          completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  void _setupCallbacks() {
    _ad?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => state = AdState.showing,
      onAdDismissedFullScreenContent: (ad) {
        state = AdState.idle;
        ad.dispose();
        _ad = null;
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        state = AdState.failed;
        ad.dispose();
        _ad = null;
        onError?.call('${error.code}: ${error.message}');
      },
    );
  }

  @override
  Future<bool> show() async {
    if (_ad == null || state != AdState.loaded) return false;

    // Don't show expired ads
    if (_isExpired) {
      dPrint('⏰ AppOpen: Ad expired, disposing');
      _ad!.dispose();
      _ad = null;
      state = AdState.idle;
      return false;
    }

    await _ad!.show();
    return true;
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    _loadTime = null;
    state = AdState.idle;
  }
}
