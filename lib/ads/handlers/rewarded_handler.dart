import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads_types.dart';
import 'base_ad_handler.dart';
import '../d_print.dart';

class RewardedHandler extends BaseAdHandler {
  final String adUnitId;
  RewardedAd? _ad;

  bool _rewardEarned = false;
  bool get wasRewardEarned => _rewardEarned;

  // ── Preload state exposed so the sheet can read isRewardedLoading ──
  bool _isPreloading = false;
  bool get isPreloading => _isPreloading;

  VoidCallback? onDismissed;
  void Function(String error)? onError;

  RewardedHandler({required this.adUnitId});

  @override
  Future<bool> load() {
    if (state == AdState.loading) return Future.value(false);
    state = AdState.loading;
    _isPreloading = true;
    final completer = Completer<bool>();

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          state = AdState.loaded;
          _isPreloading = false;
          completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          state = AdState.failed;
          _isPreloading = false;
          dPrint('❌ Rewarded load failed: ${error.message}');
          completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  /// Shows ad and returns true if reward was earned.
  /// [onUserEarnedReward] is called when user earns reward DURING the ad.
  @override
  Future<bool> show({Future<void> Function()? onUserEarnedReward}) async {
    if (_ad == null || state != AdState.loaded) return false;

    _rewardEarned = false;
    final completer = Completer<bool>();
    final adToShow = _ad!;
    _ad = null;

    adToShow.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        state = AdState.showing;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onAdDismissedFullScreenContent: (ad) {
        _restoreUI();
        state = AdState.idle;
        ad.dispose();
        onDismissed?.call();
        completer.complete(_rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _restoreUI();
        state = AdState.failed;
        ad.dispose();
        onError?.call('${error.code}: ${error.message}');
        completer.complete(false);
      },
    );

    adToShow.show(
      onUserEarnedReward: (ad, reward) async {
        dPrint('🎉 Reward earned: ${reward.type} × ${reward.amount}');
        _rewardEarned = true;
        await onUserEarnedReward?.call();
      },
    );

    return completer.future;
  }

  void _restoreUI() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  void resetReward() => _rewardEarned = false;

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    state = AdState.idle;
    _isPreloading = false;
    _rewardEarned = false;
  }
}
