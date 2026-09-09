import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
}
