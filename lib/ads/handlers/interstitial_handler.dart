import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads_types.dart';
import 'base_ad_handler.dart';
import '../d_print.dart';

class InterstitialHandler extends BaseAdHandler {
  final String adUnitId;
  InterstitialAd? _ad;

  /// Callbacks
  VoidCallback? onDismissed;
  VoidCallback? onClicked;
  void Function(String error)? onError;

  InterstitialHandler({required this.adUnitId});

  @override
  Future<bool> load() {
    if (state == AdState.loading) return Future.value(false);
    state = AdState.loading;
    final completer = Completer<bool>();

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          state = AdState.loaded;
          _setupCallbacks();
          completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          state = AdState.failed;
          dPrint('❌ Interstitial load failed: ${error.message}');
          completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  void _setupCallbacks() {
    _ad?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        state = AdState.showing;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onAdDismissedFullScreenContent: (ad) {
        _restoreUI();
        state = AdState.idle;
        ad.dispose();
        _ad = null;
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _restoreUI();
        state = AdState.failed;
        ad.dispose();
        _ad = null;
        onError?.call('${error.code}: ${error.message}');
      },
      // 🟢 2. CATCH THE CLICK EVENT
      onAdClicked: (ad) {
        dPrint('🖱️ Interstitial Ad Clicked!');
        onClicked?.call();
      },
    );
  }

  @override
  Future<bool> show() async {
    if (_ad == null || state != AdState.loaded) return false;
    try {
      await _ad!.show();
      return true;
    } catch (e) {
      dPrint('❌ Interstitial show exception: $e');
      _restoreUI();
      state = AdState.failed;
      _ad?.dispose();
      _ad = null;
      return false;
    }
  }

  void _restoreUI() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    state = AdState.idle;
  }
}
