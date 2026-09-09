import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'ads_connectivity.dart';
import 'ads_key_provider.dart';
import 'ads_retry_manager.dart';
import 'ads_types.dart';
import 'd_print.dart';
import 'handlers/app_open_handler.dart';
import 'handlers/banner_handler.dart';
import 'handlers/interstitial_handler.dart';
import 'handlers/native_handler.dart';
import 'handlers/rewarded_handler.dart';
import 'widgets/banner_ad_controller.dart';

typedef ProChecker = bool Function();
typedef AdsConsentChecker = Future<bool> Function();

class AdsService with WidgetsBindingObserver {
  // ══════════════ SINGLETON ══════════════

  static AdsService? _instance;

  VoidCallback? onAdClicked;
  static bool get isInitialized => _instance?._initialized ?? false;

  /// Safe instance: never throws, even if initialize() was never called.
  static AdsService get instance {
    _instance ??= AdsService._();
    return _instance!;
  }

  AdsService._();

  // ══════════════ SAFE DEFAULT CONFIG (no-op mode) ══════════════
  static const AdsConfig _disabledConfig = AdsConfig(
    adsEnabled: false,
    preloadEnabled: false,
    bannerEnabled: false,
    interstitialEnabled: false,
    nativeEnabled: false,
    appOpenEnabled: false,
    rewardedEnabled: false,
    directInterstitialEnabled: false,
    interstitialAfter: 0,
  );

  // ══════════════ STATE ══════════════

  AdsConfig _config = _disabledConfig;
  AdsRetryManager _retryManager = AdsRetryManager(_disabledConfig);
  AdsKeyProvider? _keyProvider;
  AdsConsentChecker? _consentChecker;
  bool _consentAllowed = true;
  bool _lifecycleObserverRegistered = false;

  AdsConfig get config => _config;

  bool _initialized = false;

  /// Pro check function — no BuildContext
  ProChecker _isProUser = () => false;

  /// True only when ads are enabled and the configured consent gate allows
  /// ad requests. With no consent checker, this remains true for backwards
  /// compatibility with the original package behavior.
  bool get _isSafeToOperate =>
      _initialized && _config.adsEnabled && _consentAllowed;

  bool get canRequestAds => _consentAllowed;

  // ── Handlers ──
  InterstitialHandler? _interstitialHandler;
  RewardedHandler? _rewardedHandler;
  BannerHandler? _bannerHandler;
  NativeHandler? _nativeHandler;
  AppOpenHandler? _appOpenHandler;
  InterstitialHandler? _directInterstitialHandler;

  // ── Interstitial frequency ──
  int _screenCount = 0;
  VoidCallback? _pendingNavCallback;

  // ── Interstitial load guard: prevents parallel in-flight load requests ──
  bool _interstitialLoadInProgress = false;

  // ── App Open ──
  // ── App Open suppression ──
  bool _eligibleForAppOpen = false;
  bool _interstitialJustDismissed = false;

  // ── Banner controller ──
  final BannerAdController _bannerController = BannerAdController();

  BannerAdController get bannerController => _bannerController;

  // Convenience getters (must be safe pre-init)
  bool get hasBanner => _isSafeToOperate && _config.isBannerAvailable;
  bool get hasInterstitial =>
      _isSafeToOperate && _config.isInterstitialAvailable;
  bool get hasRewarded => _isSafeToOperate && _config.isRewardedAvailable;
  bool get hasNative => _isSafeToOperate && _config.isNativeAvailable;
  bool get hasAppOpen => _isSafeToOperate && _config.isAppOpenAvailable;
  bool get hasDirectInterstitial =>
      _isSafeToOperate && _config.isDirectInterstitialAvailable;

  bool get canShowBanner => hasBanner && !_isProUser();

  String? get bannerAdUnitId {
    if (!canShowBanner) return null;
    return _config.adIdFor(AdType.banner);
  }

  bool get isRewardedReady => _rewardedHandler?.isLoaded == true;
  bool get isRewardedLoading => _rewardedHandler?.state == AdState.loading;

  // ══════════════════════════════════════════════════════════
  //  INITIALIZATION
  // ══════════════════════════════════════════════════════════

  static Future<AdsService> initialize({
    required AdsKeyProvider keyProvider,
    ProChecker? isProUser,
    AdsConsentChecker? consentChecker,
  }) async {
    // ✅ If already initialized, return.
    if (_instance != null && _instance!._initialized) return _instance!;

    // ✅ Reuse existing instance (even if created via instance getter)
    final service = _instance ?? AdsService._();
    _instance = service;

    if (isProUser != null) service._isProUser = isProUser;
    service._keyProvider = keyProvider;
    service._consentChecker = consentChecker;

    // Init MobileAds (safe to call multiple times)
    await MobileAds.instance.initialize();

    // Fetch config
    final fetchedConfig = await keyProvider.getConfig();
    service._consentAllowed = await service._readConsent();
    service._config = service._configWithConsent(fetchedConfig);
    service._retryManager = AdsRetryManager(service._config);

    // Configure connectivity
    AdsConnectivity.configure(
      recheckInterval: service._config.connectivityRecheckInterval,
    );

    // Mark initialized even if ads are disabled — so app won't try re-init loops
    service._initialized = true;

    if (!service._config.adsEnabled || !service._consentAllowed) {
      dPrint(
        '🚫 AdsService: ads are currently unavailable (initialized in no-ads mode)',
      );
      return service;
    }

    // Create handlers for available types
    service._createHandlers();

    // Observer only matters if appOpen is enabled
    service._addLifecycleObserver();

    // Preload
    if (service._config.preloadEnabled && !service._isProUser()) {
      service._preloadAll();
    }

    dPrint('✅ AdsService initialized: ${service._config.availableAdTypes}');
    return service;
  }

  void _createHandlers() {
    if (_config.isDirectInterstitialAvailable) {
      _directInterstitialHandler = InterstitialHandler(
        adUnitId: _config.adIdFor(AdType.directInterstitial)!,
      );
    }

    if (_config.isInterstitialAvailable) {
      _interstitialHandler = InterstitialHandler(
        adUnitId: _config.adIdFor(AdType.interstitial)!,
      );
      _interstitialHandler!.onDismissed = _onInterstitialDismissed;
      _interstitialHandler!.onClicked = () {
        onAdClicked?.call();
      };
    }

    if (_config.isRewardedAvailable) {
      _rewardedHandler = RewardedHandler(
        adUnitId: _config.adIdFor(AdType.rewarded)!,
      );
    }

    if (_config.isBannerAvailable) {
      _bannerHandler = BannerHandler(adUnitId: _config.adIdFor(AdType.banner)!);
    }

    if (_config.isNativeAvailable) {
      _nativeHandler = NativeHandler(adUnitId: _config.adIdFor(AdType.native)!);
    }

    if (_config.isAppOpenAvailable) {
      _appOpenHandler = AppOpenHandler(
        adUnitId: _config.adIdFor(AdType.appOpen)!,
      );

      _appOpenHandler!.onDismissed = () {
        _bannerController.onDialogClosed();
        _loadWithRetry(AdType.appOpen);
      };
      _appOpenHandler!.onError = (_) {
        _bannerController.onDialogClosed();
        _loadWithRetry(AdType.appOpen);
      };
    }
  }

  // ══════════════════════════════════════════════════════════
  //  LOADING
  // ══════════════════════════════════════════════════════════

  Future<bool> _loadWithRetry(AdType type, {int? maxAttempts}) async {
    if (!_isSafeToOperate) return false;
    if (_isProUser()) return false;

    final handler = _handlerFor(type);
    if (handler == null) return false;
    if (handler.isLoaded) return true;

    final online = await AdsConnectivity.check();
    if (!online) return false;

    return _retryManager.retry(
      () => handler.load(),
      label: type.name,
      maxAttempts: maxAttempts,
    );
  }

  /// Starts a background interstitial load only if one isn't already in-flight.
  /// This prevents the parallel-request explosion when ads aren't cached yet.
  void _ensureInterstitialLoading() {
    if (_interstitialLoadInProgress) return;
    if (_interstitialHandler?.isLoaded == true) return;

    _interstitialLoadInProgress = true;
    _loadWithRetry(AdType.interstitial).then((_) {
      _interstitialLoadInProgress = false;
    });
  }

  dynamic _handlerFor(AdType type) => switch (type) {
    AdType.interstitial => _interstitialHandler,
    AdType.rewarded => _rewardedHandler,
    AdType.banner => _bannerHandler,
    AdType.native => _nativeHandler,
    AdType.appOpen => _appOpenHandler,
    AdType.directInterstitial => _directInterstitialHandler,
  };

  void _preloadAll() {
    if (!_isSafeToOperate) return;
    if (_isProUser()) return;

    for (final type in _config.availableAdTypes) {
      if (type == AdType.banner) continue;

      // Native & splash: one attempt only
      if (type == AdType.native || type == AdType.directInterstitial) {
        _loadWithRetry(type, maxAttempts: 0);
      } else if (type == AdType.interstitial) {
        // Use the guarded loader for interstitial to prevent parallel requests
        _ensureInterstitialLoading();
      } else {
        _loadWithRetry(type); // rewarded/appOpen use config retry policy
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  //  APP LIFECYCLE (App Open)
  // ══════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isSafeToOperate) return;
    if (!_config.isAppOpenAvailable || _isProUser()) return;

    if (state == AppLifecycleState.paused) _eligibleForAppOpen = true;

    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_eligibleForAppOpen &&
            !_interstitialJustDismissed &&
            _appOpenHandler?.isShowing != true) {
          showAppOpen();
        }
        _eligibleForAppOpen = false;
        _interstitialJustDismissed = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════

  void setProChecker(ProChecker checker) => _isProUser = checker;

  /// Called on every screen visit to passively track frequency.
  /// Does NOT trigger a load — only shows if an ad is already cached.
  /// Use [showBeforeNavigation] for navigation-gated ad display instead.
  void onScreenVisit() {
    if (!_isSafeToOperate || !hasInterstitial || _isProUser()) return;

    _screenCount++;
    if (_screenCount >= _config.interstitialAfter) {
      _screenCount = 0;
      // Only show if already loaded — never trigger a load here.
      _triggerInterstitialIfReady();
    }
  }

  /// Shows an interstitial before navigation when the threshold is met.
  /// Counter is only reset if an ad was actually ready to show.
  /// If no ad is cached, the user navigates freely and a background load starts.
  void showBeforeNavigation(VoidCallback onComplete) {
    if (!_isSafeToOperate || !hasInterstitial || _isProUser()) {
      onComplete();
      return;
    }

    // Check if incrementing would meet the threshold
    if (_screenCount + 1 >= _config.interstitialAfter) {
      if (_interstitialHandler?.isLoaded == true) {
        // Ad is ready — consume the threshold and show
        _screenCount = 0;
        _pendingNavCallback = onComplete;
        _triggerInterstitialIfReady();
      } else {
        // Ad not ready — let user navigate freely, start a background load.
        // Counter is NOT reset so the next navigation will retry immediately.
        onComplete();
        _ensureInterstitialLoading();
      }
    } else {
      _screenCount++;
      onComplete();
    }
  }

  /// Shows an interstitial immediately, bypassing the screen counter.
  /// Returns false if no ad is loaded — does NOT trigger a load.
  Future<bool> showInterstitialNow() async {
    if (!_isSafeToOperate || !hasInterstitial || _isProUser()) return false;
    if (_interstitialHandler?.isLoaded != true) return false;
    return _interstitialHandler!.show();
  }

  /// Internal: show the interstitial only if it's already loaded.
  /// Separation of concerns — this method never loads, only shows.
  void _triggerInterstitialIfReady() {
    if (_interstitialHandler?.isLoaded != true) {
      _firePendingNav();
      return;
    }

    _interstitialHandler!.show().then((shown) {
      if (!shown) _firePendingNav();
    });
  }

  /// Splash/direct interstitial: never reload, never retry-on-call.
  void showDirect({
    VoidCallback? onDismissed,
    VoidCallback? onResumeNavigation,
  }) {
    if (!_isSafeToOperate) {
      dPrint('Not Safe to Operate Resuming');
      onResumeNavigation?.call();
      return;
    }

    if (!hasDirectInterstitial || _isProUser()) {
      dPrint('Not Have Direct Ad Resuming');
      onResumeNavigation?.call();
      return;
    }

    if (_directInterstitialHandler?.isLoaded != true) {
      dPrint('⏭️ Splash Ad not ready in time. Skipping.');
      onResumeNavigation?.call();
      return;
    }

    final handler = _directInterstitialHandler!;
    final originalOnDismissed = handler.onDismissed;
    final originalOnError = handler.onError;
    var navigationResumed = false;

    void resumeNavigation() {
      if (navigationResumed) return;
      navigationResumed = true;
      onResumeNavigation?.call();
    }

    void restoreCallbacks() {
      handler.onDismissed = originalOnDismissed;
      handler.onError = originalOnError;
    }

    handler.onDismissed = () {
      _interstitialJustDismissed = true;
      onDismissed?.call();
      resumeNavigation();
      restoreCallbacks();
    };

    handler.onError = (error) {
      _interstitialJustDismissed = true;
      resumeNavigation();
      restoreCallbacks();
      originalOnError?.call(error);
    };

    handler.show().then((shown) {
      if (!shown) {
        resumeNavigation();
        restoreCallbacks();
      }
    });
  }

  void _onInterstitialDismissed() {
    if (!_isSafeToOperate) return;
    _interstitialJustDismissed = true;
    _firePendingNav();

    // Reload after dismiss — guarded so only one in-flight request at a time.
    Future.delayed(
      const Duration(milliseconds: 500),
      _ensureInterstitialLoading,
    );
  }

  void _firePendingNav() {
    if (_pendingNavCallback != null) {
      final cb = _pendingNavCallback;
      _pendingNavCallback = null;
      Future.delayed(const Duration(milliseconds: 100), cb);
    }
  }

  int get visitsUntilNextAd => (_config.interstitialAfter - _screenCount).clamp(
    0,
    _config.interstitialAfter,
  );

  void resetCounter() => _screenCount = 0;

  Future<void> preloadRewarded() async {
    if (!_isSafeToOperate) return;
    await _loadWithRetry(AdType.rewarded);
  }

  Future<bool> showRewarded({
    Future<void> Function()? onUserEarnedReward,
    VoidCallback? onDismissed,
  }) async {
    // Pro users always get reward free (even if ads never initialized)
    if (_isProUser()) {
      await onUserEarnedReward?.call();
      onDismissed?.call();
      return true;
    }

    if (!_isSafeToOperate) return false;

    if (!hasRewarded || _rewardedHandler == null) return false;

    if (!_rewardedHandler!.isLoaded) {
      final loaded = await _loadWithRetry(AdType.rewarded);
      if (!loaded) return false;
    }

    _rewardedHandler!.onDismissed = () {
      onDismissed?.call();
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _loadWithRetry(AdType.rewarded),
      );
    };

    return _rewardedHandler!.show(onUserEarnedReward: onUserEarnedReward);
  }

  Future<bool> loadNative({NativeTemplateSize? size, int? maxAttempts}) async {
    if (!_isSafeToOperate) return false;
    if (!hasNative || _isProUser()) return false;

    if (size != null && _config.isNativeAvailable) {
      _nativeHandler?.dispose();
      _nativeHandler = NativeHandler(
        adUnitId: _config.adIdFor(AdType.native)!,
        templateSize: size,
      );
    }

    return _loadWithRetry(AdType.native, maxAttempts: maxAttempts);
  }

  NativeHandler? get nativeHandler => _nativeHandler;

  Future<bool> showAppOpen() async {
    if (!_isSafeToOperate) return false;
    if (!hasAppOpen || _isProUser()) return false;
    if (isAppOpenBlocked) {
      if (_skipNextAppOpen) {
        _skipNextAppOpen = false;
        dPrint('⏭️ AppOpen: skipped one opportunity');
      } else {
        dPrint('🛡️ AppOpen: blocked while a protected flow is active');
      }
      return false;
    }
    if (_appOpenHandler == null) return false;

    if (!_appOpenHandler!.isLoaded) {
      final loaded = await _loadWithRetry(AdType.appOpen);
      if (!loaded) return false;
    }

    _bannerController.onDialogOpened();
    final shown = await _appOpenHandler!.show();

    if (!shown) {
      _bannerController.onDialogClosed();
      _loadWithRetry(AdType.appOpen);
    }

    return shown;
  }

  Future<void> refreshConfig() async {
    final provider = _keyProvider;
    if (provider == null) return;

    final newConfig = await provider.getConfig();
    _consentAllowed = await _readConsent();
    _disposeHandlers();
    _config = _configWithConsent(newConfig);
    _retryManager = AdsRetryManager(_config);
    _interstitialLoadInProgress = false;
    if (_config.adsEnabled) {
      _createHandlers();
      _addLifecycleObserver();
      if (_config.preloadEnabled) _preloadAll();
    }
  }

  /// Re-reads the UMP decision after the user changes privacy settings.
  ///
  /// When consent is revoked, existing handlers are disposed immediately so
  /// future loads and shows cannot continue using the old decision. When it is
  /// granted again, the current Remote Config/ID configuration is rebuilt.
  Future<void> refreshConsent() async {
    if (_consentChecker == null) return;

    _consentAllowed = await _readConsent();
    if (!_consentAllowed) {
      _disposeHandlers();
      _config = _config.copyWith(adsEnabled: false, preloadEnabled: false);
      _retryManager = AdsRetryManager(_config);
      return;
    }

    await refreshConfig();
  }

  void _disposeHandlers() {
    _interstitialHandler?.dispose();
    _rewardedHandler?.dispose();
    _bannerHandler?.dispose();
    _nativeHandler?.dispose();
    _appOpenHandler?.dispose();
    _directInterstitialHandler?.dispose();

    _interstitialHandler = null;
    _rewardedHandler = null;
    _bannerHandler = null;
    _nativeHandler = null;
    _appOpenHandler = null;
    _directInterstitialHandler = null;
  }

  void dispose() {
    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverRegistered = false;
    }
    _disposeHandlers();
    clearAppOpenBlockers();
    _screenCount = 0;
    _pendingNavCallback = null;
    _interstitialLoadInProgress = false;
  }

  static void reset() {
    _instance?.dispose();
    _instance = null;
    AdsConnectivity.reset();
  }

  Map<String, dynamic> getDebugState() => {
    'initialized': _initialized,
    'consentAllowed': _consentAllowed,
    'config': _config.toString(),
    'isPro': _isProUser(),
    'connectivity': AdsConnectivity.isOnline,
    'interstitial': {
      'available': hasInterstitial,
      'loaded': _interstitialHandler?.isLoaded ?? false,
      'loadInProgress': _interstitialLoadInProgress,
      'screenCount': _screenCount,
      'showAfter': _config.interstitialAfter,
      'visitsUntilNext': visitsUntilNextAd,
    },
    'rewarded': {
      'available': hasRewarded,
      'loaded': _rewardedHandler?.isLoaded ?? false,
    },
    'banner': {
      'available': hasBanner,
      'loaded': _bannerHandler?.isLoaded ?? false,
    },
    'native': {
      'available': hasNative,
      'loaded': _nativeHandler?.isLoaded ?? false,
    },
    'appOpen': {
      'available': hasAppOpen,
      'loaded': _appOpenHandler?.isLoaded ?? false,
    },
  };

  //==============================================
  //          App Open Ad Suppression
  //==============================================

  /// One-shot: skip exactly the next app-open opportunity, then auto-reset.
  bool _skipNextAppOpen = false;

  /// Named blockers for long-running flows (camera, picker, permissions...).
  /// As long as the set is non-empty, app open ads are suppressed.
  final Set<String> _appOpenBlockers = {};

  /// Safety timers so a forgotten unblock can't kill app-open ads forever.
  final Map<String, Timer> _blockerTimeouts = {};

  /// Default safety timeout for a blocker (configurable per call).
  static const Duration _defaultBlockerTimeout = Duration(minutes: 5);

  bool get isAppOpenBlocked => _skipNextAppOpen || _appOpenBlockers.isNotEmpty;

  // ══════════════ PUBLIC SUPPRESSION API ══════════════

  /// Skip the next app-open ad opportunity (one-shot).
  /// Use right before launching something that briefly leaves the app:
  /// permission dialogs, openAppSettings(), share sheet, intent chooser...
  void skipNextAppOpen() {
    _skipNextAppOpen = true;
    dPrint('🛡️ AppOpen: next show will be skipped');
  }

  /// Cancel a pending one-shot skip (rarely needed).
  void cancelSkipNextAppOpen() => _skipNextAppOpen = false;

  /// Block app-open ads until [unblockAppOpen] is called with the same reason.
  /// [timeout] is a safety net — the blocker auto-clears after it elapses,
  /// so a missed unblock can't permanently disable app-open ads.
  void blockAppOpen(
    String reason, {
    Duration timeout = _defaultBlockerTimeout,
  }) {
    _appOpenBlockers.add(reason);
    _blockerTimeouts[reason]?.cancel();
    _blockerTimeouts[reason] = Timer(timeout, () {
      if (_appOpenBlockers.remove(reason)) {
        dPrint('⏰ AppOpen blocker "$reason" auto-expired');
      }
      _blockerTimeouts.remove(reason);
    });
    dPrint('🛡️ AppOpen blocked: $reason (active: $_appOpenBlockers)');
  }

  /// Remove a named blocker.
  void unblockAppOpen(String reason) {
    _appOpenBlockers.remove(reason);
    _blockerTimeouts.remove(reason)?.cancel();
    dPrint('✅ AppOpen unblocked: $reason (active: $_appOpenBlockers)');
  }

  /// Clear everything (e.g. on logout / route reset).
  void clearAppOpenBlockers() {
    _appOpenBlockers.clear();
    for (final t in _blockerTimeouts.values) {
      t.cancel();
    }
    _blockerTimeouts.clear();
    _skipNextAppOpen = false;
  }

  /// Convenience: run any async action with app-open ads suppressed.
  /// Guaranteed to unblock even if the action throws.
  Future<T> runWithoutAppOpen<T>(
    Future<T> Function() action, {
    String reason = 'scoped_action',
    Duration timeout = _defaultBlockerTimeout,

    /// Small grace period after the action completes — covers the
    /// resume animation/lifecycle callback that fires *after* the
    /// picker/camera returns.
    Duration releaseDelay = const Duration(seconds: 1),
  }) async {
    blockAppOpen(reason, timeout: timeout);
    try {
      return await action();
    } finally {
      Future.delayed(releaseDelay, () => unblockAppOpen(reason));
    }
  }

  void dPrintDebug() {
    dPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    dPrint('📊 AdsService Debug');
    getDebugState().forEach((k, v) => dPrint('   $k: $v'));
    dPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  Future<bool> _readConsent() async {
    final checker = _consentChecker;
    if (checker == null) return true;

    try {
      final allowed = await checker();
      if (!allowed) dPrint('🛡️ AdsService: consent gate is blocking ad requests');
      return allowed;
    } catch (error) {
      dPrint('⚠️ AdsService: consent check failed; blocking ads: $error');
      return false;
    }
  }

  AdsConfig _configWithConsent(AdsConfig config) {
    if (_consentAllowed) return config;
    return config.copyWith(adsEnabled: false, preloadEnabled: false);
  }

  void _addLifecycleObserver() {
    if (_lifecycleObserverRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverRegistered = true;
  }
}
