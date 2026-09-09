import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads_service.dart';
import '../d_print.dart';
import 'banner_ad_shimmer.dart';

export 'banner_ad_shimmer.dart';

class SmartBannerAdWidget extends StatefulWidget {
  final EdgeInsets padding;
  final bool collapsible;
  final bool showAd;
  final Widget? loadingWidget;
  final Widget? placeholder;

  const SmartBannerAdWidget({
    super.key,
    this.padding = EdgeInsets.zero,
    this.collapsible = false,
    this.showAd = true,
    this.loadingWidget,
    this.placeholder,
  });

  @override
  State<SmartBannerAdWidget> createState() => _SmartBannerAdWidgetState();
}

class _SmartBannerAdWidgetState extends State<SmartBannerAdWidget> {
  BannerAd? _bannerAd;
  AdSize? _size;
  bool _loaded = false;
  bool _isFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  Future<void> _loadIfNeeded() async {
    if (_bannerAd != null) return;

    // ✅ FIX: Check if AdsService is ready BEFORE calling .instance
    if (!AdsService.isInitialized) {
      dPrint('⏳ Banner skip: AdsService not initialized yet');
      return;
    }

    // Now it's 100% safe to call .instance
    final ads = AdsService.instance;

    if (!widget.showAd || !ads.canShowBanner) {
      dPrint(
        '🙈 Banner skip: showAd=${widget.showAd}, canShow=${ads.canShowBanner}',
      );
      return;
    }

    final adUnitId = ads.bannerAdUnitId;
    if (adUnitId == null || adUnitId.isEmpty) {
      dPrint('❌ Banner skip: Ad Unit ID is empty');
      return;
    }

    final width = MediaQuery.of(context).size.width.truncate();
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );

    if (!mounted || size == null) {
      dPrint('❌ Banner skip: Adaptive size could not be calculated');
      return;
    }

    _size = size;
    dPrint('📱 Banner loading: width=$width, id=$adUnitId');

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: widget.collapsible
          ? const AdRequest(extras: {'collapsible': 'bottom'})
          : const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          dPrint('✅ Banner loaded successfully');
          if (!mounted) return;
          final platformSize = await (ad as BannerAd).getPlatformAdSize();
          if (!mounted) return;
          setState(() {
            if (platformSize != null) {
              _size = platformSize;
            }
            _loaded = true;
            _isFailed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          dPrint('❌ Banner load failed: [${error.code}] ${error.message}');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _loaded = false;
            _isFailed = true;
            _size = null;
          });
        },
      ),
    );

    setState(() => _bannerAd = ad);
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Check if initialized here too!
    if (!AdsService.isInitialized) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    final ads = AdsService.instance;

    if (!widget.showAd || !ads.canShowBanner) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    final ctrl = ads.bannerController;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (_, _) {
        if (ctrl.shouldHideBanner) {
          return widget.placeholder ?? const SizedBox.shrink();
        }

        if (_isFailed) {
          return widget.placeholder ?? const SizedBox.shrink();
        }

        if (!_loaded || _bannerAd == null || _size == null) {
          final defaultLoader = BannerAdShimmer(
            width: _size?.width.toDouble(),
            height: _size?.height.toDouble(),
          );
          final loaderChild = widget.loadingWidget ?? defaultLoader;

          if (widget.padding == EdgeInsets.zero) {
            return loaderChild;
          }

          return Padding(padding: widget.padding, child: loaderChild);
        }

        final adChild = SizedBox(
          width: _size!.width.toDouble(),
          height: _size!.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        );

        if (widget.padding == EdgeInsets.zero) {
          return adChild;
        }

        return Padding(padding: widget.padding, child: adChild);
      },
    );
  }
}
