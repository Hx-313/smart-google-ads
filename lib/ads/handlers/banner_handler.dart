import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads_types.dart';
import 'base_ad_handler.dart';
import '../d_print.dart';

class BannerHandler extends BaseAdHandler {
  final String adUnitId;
  BannerAd? _ad;
  AdSize? _adSize;

  BannerHandler({required this.adUnitId});

  BannerAd? get ad => _ad;
  AdSize? get adSize => _adSize;

  /// Load an adaptive banner. Must be called with screen width.
  Future<bool> loadAdaptive({
    required double screenWidth,
    bool collapsible = false,
  }) async {
    if (state == AdState.loading) return false;

    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      screenWidth.truncate(),
    );
    if (size == null) return false;

    _adSize = size;
    return _loadWithSize(size, collapsible: collapsible);
  }

  Future<bool> _loadWithSize(AdSize size, {bool collapsible = false}) {
    state = AdState.loading;
    final completer = Completer<bool>();

    _ad = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: collapsible
          ? const AdRequest(extras: {'collapsible': 'bottom'})
          : const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final platformSize = await (ad as BannerAd).getPlatformAdSize();
          if (platformSize != null) {
            _adSize = platformSize;
          }
          state = AdState.loaded;
          completer.complete(true);
        },
        onAdFailedToLoad: (ad, error) {
          dPrint('❌ Banner load failed: ${error.message}');
          state = AdState.failed;
          ad.dispose();
          _ad = null;
          completer.complete(false);
        },
      ),
    )..load();

    return completer.future;
  }

  @override
  Future<bool> load() => Future.value(false); // Use loadAdaptive instead

  @override
  Future<bool> show() async => isLoaded && _ad != null;

  Widget get widget {
    if (_ad == null || _adSize == null) return const SizedBox.shrink();
    return SizedBox(
      width: _adSize!.width.toDouble(),
      height: _adSize!.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    _adSize = null;
    state = AdState.idle;
  }
}
