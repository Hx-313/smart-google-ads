import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';

import 'package:smart_google_ads/smart_google_ads.dart';

class _FakeConsentClient implements AdsConsentClient {
  bool failConsentUpdate = false;
  bool failForm = false;
  bool allowed = true;
  AdsConsentStatus currentStatus = AdsConsentStatus.obtained;
  int updateCalls = 0;
  int formCalls = 0;

  @override
  Future<bool> canRequestAds() async => allowed;

  @override
  Future<AdsConsentStatus> getConsentStatus() async => currentStatus;

  @override
  Future<bool> isPrivacyOptionsRequired() async => true;

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    formCalls++;
    if (failForm) throw StateError('form failed');
  }

  @override
  Future<void> requestConsentInfoUpdate(AdsConsentOptions options) async {
    updateCalls++;
    if (failConsentUpdate) throw StateError('update failed');
  }

  @override
  Future<void> showPrivacyOptionsForm() async {}
}

void main() {
  test('selects the debug ID in debug builds', () {
    const ids = PlatformAdIds(
      debug: 'debug-id',
      android: 'android-id',
      ios: 'ios-id',
    );

    expect(ids.current, 'debug-id');
    expect(ids.isAvailable, isTrue);
  });

  test('builds an available config from explicitly supplied IDs', () {
    const ids = AdsAdUnitIds(
      banner: PlatformAdIds(debug: 'banner-id'),
      rewarded: PlatformAdIds(debug: 'rewarded-id'),
    );

    final config = ids.toConfig();

    expect(config.isBannerAvailable, isTrue);
    expect(config.isRewardedAvailable, isTrue);
    expect(config.isInterstitialAvailable, isFalse);
    expect(config.nativeEnabled, isFalse);
  });

  test('remote config options default to enabled with safe fetch settings', () {
    const options = AdsRemoteConfigOptions();

    expect(options.enabled, isTrue);
    expect(options.fetchTimeout, const Duration(seconds: 10));
    expect(options.minimumFetchInterval, const Duration(hours: 6));
  });

  test('omitted consent is disabled in debug and enabled in release', () {
    expect(
      AdsBootstrap.resolveConsentOptions(debug: true).enabled,
      isFalse,
    );
    expect(
      AdsBootstrap.resolveConsentOptions(debug: false).enabled,
      isTrue,
    );

    const explicit = AdsConsentOptions.disabled();
    expect(
      AdsBootstrap.resolveConsentOptions(
        consent: explicit,
        debug: false,
      ).enabled,
      isFalse,
    );
  });

  test('does not initialize Mobile Ads when consent denies ad access', () async {
    AdsService.reset();
    var sdkInitialized = false;
    const config = AdsConfig(
      bannerIds: PlatformAdIds(debug: 'banner-id'),
      bannerEnabled: true,
      interstitialEnabled: false,
      nativeEnabled: false,
      appOpenEnabled: false,
      rewardedEnabled: false,
      directInterstitialEnabled: false,
      preloadEnabled: false,
    );

    try {
      final ads = await AdsService.initialize(
        keyProvider: const DirectAdsKeyProvider(config),
        consentChecker: () async => false,
        sdkInitializer: () async => sdkInitialized = true,
      );

      expect(sdkInitialized, isFalse);
      expect(AdsService.isInitialized, isTrue);
      expect(ads.hasBanner, isFalse);
    } finally {
      AdsService.reset();
    }
  });

  test('initializes Mobile Ads when consent is later granted', () async {
    AdsService.reset();
    var consentAllowed = false;
    var sdkInitializations = 0;
    const config = AdsConfig(
      bannerIds: PlatformAdIds(debug: 'banner-id'),
      bannerEnabled: true,
      interstitialEnabled: false,
      nativeEnabled: false,
      appOpenEnabled: false,
      rewardedEnabled: false,
      directInterstitialEnabled: false,
      preloadEnabled: false,
    );

    try {
      final ads = await AdsService.initialize(
        keyProvider: const DirectAdsKeyProvider(config),
        consentChecker: () async => consentAllowed,
        sdkInitializer: () async => sdkInitializations++,
      );

      expect(sdkInitializations, 0);
      expect(ads.hasBanner, isFalse);

      consentAllowed = true;
      await ads.refreshConsent();

      expect(sdkInitializations, 1);
      expect(ads.hasBanner, isTrue);
    } finally {
      AdsService.reset();
    }
  });

  test('initializes Mobile Ads before creating ad handlers', () async {
    AdsService.reset();
    final events = <String>[];
    const config = AdsConfig(
      bannerIds: PlatformAdIds(debug: 'banner-id'),
      bannerEnabled: true,
      interstitialEnabled: false,
      nativeEnabled: false,
      appOpenEnabled: false,
      rewardedEnabled: false,
      directInterstitialEnabled: false,
      preloadEnabled: false,
    );

    try {
      final ads = await AdsService.initialize(
        keyProvider: const DirectAdsKeyProvider(config),
        consentChecker: () async => true,
        sdkInitializer: () async => events.add('sdk-init'),
      );

      expect(events, ['sdk-init']);
      expect(ads.hasBanner, isTrue);
    } finally {
      AdsService.reset();
    }
  });

  test('fails closed when Mobile Ads initialization throws', () async {
    AdsService.reset();
    const config = AdsConfig(
      bannerIds: PlatformAdIds(debug: 'banner-id'),
      bannerEnabled: true,
      interstitialEnabled: false,
      nativeEnabled: false,
      appOpenEnabled: false,
      rewardedEnabled: false,
      directInterstitialEnabled: false,
      preloadEnabled: false,
    );

    try {
      final ads = await AdsService.initialize(
        keyProvider: const DirectAdsKeyProvider(config),
        sdkInitializer: () async => throw StateError('sdk failed'),
      );

      expect(AdsService.isInitialized, isTrue);
      expect(ads.hasBanner, isFalse);
    } finally {
      AdsService.reset();
    }
  });

  test('UMP consent is requested before ad access is granted', () async {
    final client = _FakeConsentClient();
    final manager = AdsConsentManager(client: client);

    final allowed = await manager.requestConsent(const AdsConsentOptions());

    expect(allowed, isTrue);
    expect(manager.status, AdsConsentStatus.obtained);
    expect(client.updateCalls, 1);
    expect(client.formCalls, 1);
  });

  test('consent fails closed when UMP cannot confirm ad access', () async {
    final client = _FakeConsentClient()
      ..failConsentUpdate = true
      ..allowed = false
      ..currentStatus = AdsConsentStatus.unknown;
    Object? reportedError;
    final manager = AdsConsentManager(client: client);

    final allowed = await manager.requestConsent(
      AdsConsentOptions(onError: (error) => reportedError = error),
    );

    expect(allowed, isFalse);
    expect(manager.status, AdsConsentStatus.unknown);
    expect(reportedError, isNotNull);
  });

  test('disabled consent integration keeps the legacy ad gate open', () async {
    final client = _FakeConsentClient()..allowed = false;
    final manager = AdsConsentManager(client: client);

    final allowed = await manager.requestConsent(
      const AdsConsentOptions.disabled(),
    );

    expect(allowed, isTrue);
    expect(manager.status, AdsConsentStatus.notRequired);
    expect(client.updateCalls, 0);
    expect(client.formCalls, 0);
  });

  test('app-open coordinator reacts only to foreground and stops after dispose', () async {
    final states = StreamController<AppState>.broadcast();
    var foregroundCallbacks = 0;
    final coordinator = AppOpenLifecycleCoordinator(
      appStateStream: states.stream,
      onForeground: () => foregroundCallbacks++,
    );

    try {
      await coordinator.start();
      states
        ..add(AppState.background)
        ..add(AppState.foreground);
      await Future<void>.delayed(Duration.zero);

      expect(foregroundCallbacks, 1);

      await coordinator.dispose();
      states.add(AppState.foreground);
      await Future<void>.delayed(Duration.zero);
      expect(foregroundCallbacks, 1);
    } finally {
      await coordinator.dispose();
      await states.close();
    }
  });

  test('app-open foreground gate skips the first opportunity and resets', () {
    final gate = AppOpenForegroundGate(skippedForegrounds: 1);

    expect(gate.shouldShow(AppState.foreground), isFalse);
    expect(gate.shouldShow(AppState.foreground), isTrue);
    expect(gate.shouldShow(AppState.background), isFalse);

    gate.reset();
    expect(gate.shouldShow(AppState.foreground), isFalse);
  });

  test('policy maps to Google request restrictions', () {
    const policy = AdsPolicyOptions(
      ageTreatment: AdsAgeTreatment.child,
      maxAdContentRating: AdsMaxAdContentRating.pg,
      testDeviceIds: ['test-device'],
    );

    final configuration = policy.toRequestConfiguration();

    expect(configuration.ageRestrictedTreatment, AgeRestrictedTreatment.child);
    expect(configuration.maxAdContentRating, MaxAdContentRating.pg);
    expect(configuration.testDeviceIds, ['test-device']);
  });

  test('rewarded debug state exposes idle and loading status before init', () {
    AdsService.reset();
    final ads = AdsService.instance;
    final rewarded = ads.getDebugState()['rewarded'] as Map<String, dynamic>;

    expect(ads.rewardedState, AdState.idle);
    expect(ads.isRewardedLoading, isFalse);
    expect(rewarded['state'], 'idle');
    expect(rewarded['loading'], isFalse);
    expect(rewarded['loadInProgress'], isFalse);

    AdsService.reset();
  });

  testWidgets(
    'banner placeholder includes the animated shimmer',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BannerAdShimmer()),
      );

      expect(find.byType(Shimmer), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
