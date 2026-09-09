import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads_types.dart';
import 'base_ad_handler.dart';
import '../d_print.dart';

enum NativeTemplateSize { small, medium, large }

class NativeHandler extends BaseAdHandler {
  final String adUnitId;
  final NativeTemplateSize templateSize;
  NativeAd? _ad;

  NativeHandler({
    required this.adUnitId,
    this.templateSize = NativeTemplateSize.medium,
  });

  NativeAd? get ad => _ad;

  @override
  Future<bool> load() {
    if (state == AdState.loading) return Future.value(false);
    state = AdState.loading;
    final completer = Completer<bool>();

    _ad = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: _mapTemplate(templateSize),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          state = AdState.loaded;
          completer.complete(true);
        },
        onAdFailedToLoad: (ad, error) {
          dPrint('❌ Native load failed: ${error.message}');
          state = AdState.failed;
          ad.dispose();
          _ad = null;
          completer.complete(false);
        },
      ),
    )..load();

    return completer.future;
  }

  static TemplateType _mapTemplate(NativeTemplateSize size) => switch (size) {
    NativeTemplateSize.small => TemplateType.small,
    NativeTemplateSize.medium => TemplateType.medium,
    NativeTemplateSize.large => TemplateType.medium,
  };

  @override
  Future<bool> show() async => isLoaded && _ad != null;

  Widget get widget {
    if (_ad == null) return const SizedBox.shrink();
    return AdWidget(ad: _ad!);
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    state = AdState.idle;
  }
}
