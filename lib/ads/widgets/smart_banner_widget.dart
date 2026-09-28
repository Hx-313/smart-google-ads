import 'dart:async';

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
  static const _loadTimeout = Duration(seconds: 30);

  BannerAd? _bannerAd;
  AdSize? _size;
  bool _loaded = false;
  bool _isLoading = false;
  bool _isFailed = false;
  int _loadAttempt = 0;
  Timer? _loadTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  Future<void> _loadIfNeeded() async {
    if (_isLoading || _loaded || _bannerAd != null || _isFailed) return;

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

    final attempt = ++_loadAttempt;
    _isLoading = true;
    _loadTimer = Timer(_loadTimeout, () {
      dPrint('❌ Banner load timed out');
      _failLoad(attempt);
    });

    try {
      final adUnitId = ads.bannerAdUnitId;
      if (adUnitId == null || adUnitId.isEmpty) {
        dPrint('❌ Banner load failed: Ad Unit ID is empty');
        _failLoad(attempt);
        return;
      }

      final width = MediaQuery.of(context).size.width.truncate();
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);

      if (!mounted || !_isCurrentAttempt(attempt)) return;
      if (size == null) {
        dPrint('❌ Banner load failed: Adaptive size could not be calculated');
        _failLoad(attempt);
        return;
      }

      // Resolve the adaptive height before showing the shimmer. The shimmer
      // must never guess a fallback height while this platform call is pending.
      setState(() => _size = size);
      dPrint('📱 Banner loading: width=$width, id=$adUnitId');

      final ad = BannerAd(
        adUnitId: adUnitId,
        size: size,
        request: widget.collapsible
            ? const AdRequest(extras: {'collapsible': 'bottom'})
            : const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) async {
            if (!_isCurrentAttempt(attempt) || !identical(_bannerAd, ad)) {
              return;
            }

            try {
              dPrint('✅ Banner loaded successfully');
              final platformSize = await (ad as BannerAd).getPlatformAdSize();
              if (!_isCurrentAttempt(attempt) ||
                  !identical(_bannerAd, ad)) {
                return;
              }

              _loadTimer?.cancel();
              _loadTimer = null;
              setState(() {
                if (platformSize != null) _size = platformSize;
                _loaded = true;
                _isLoading = false;
                _isFailed = false;
              });
            } catch (error, stackTrace) {
              dPrint('❌ Banner load callback failed: $error');
              dPrint('$stackTrace');
              _failLoad(attempt);
            }
          },
          onAdFailedToLoad: (ad, error) {
            dPrint('❌ Banner load failed: [${error.code}] ${error.message}');
            _failLoad(attempt);
          },
        ),
      );

      if (!mounted || !_isCurrentAttempt(attempt)) {
        ad.dispose();
        return;
      }

      setState(() => _bannerAd = ad);
      ad.load();
    } catch (error, stackTrace) {
      dPrint('❌ Banner load exception: $error');
      dPrint('$stackTrace');
      _failLoad(attempt);
    }
  }

  bool _isCurrentAttempt(int attempt) =>
      mounted && _isLoading && attempt == _loadAttempt;

  void _failLoad(int attempt) {
    if (!_isCurrentAttempt(attempt)) return;

    _loadTimer?.cancel();
    _loadTimer = null;
    final ad = _bannerAd;
    setState(() {
      _bannerAd = null;
      _size = null;
      _loaded = false;
      _isLoading = false;
      _isFailed = true;
    });
    ad?.dispose();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _loadTimer = null;
    _loadAttempt++;
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFailed) return const SizedBox.shrink();

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

        if (_isLoading) {
          final size = _size;
          if (size == null) return const SizedBox.shrink();

          final defaultLoader = BannerAdShimmer(
            width: size.width.toDouble(),
            height: size.height.toDouble(),
          );
          final loaderChild = widget.loadingWidget ?? defaultLoader;
          final sizedLoader = SizedBox(
            width: size.width.toDouble(),
            height: size.height.toDouble(),
            child: ClipRect(child: loaderChild),
          );

          if (widget.padding == EdgeInsets.zero) {
            return sizedLoader;
          }

          return Padding(padding: widget.padding, child: sizedLoader);
        }

        if (!_loaded || _bannerAd == null || _size == null) {
          return const SizedBox.shrink();
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
