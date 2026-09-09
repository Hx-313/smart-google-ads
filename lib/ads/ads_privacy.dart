import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'd_print.dart';

/// Consent status exposed without requiring callers to depend on UMP types.
enum AdsConsentStatus { unknown, required, obtained, notRequired }

/// Debug geographies supported by Google's User Messaging Platform (UMP).
///
/// These values affect test devices only. Never use a debug geography in a
/// production build.
enum AdsConsentDebugGeography { disabled, eea, regulatedUsState, other }

/// Opt-in configuration for Google's UMP consent flow.
///
/// Passing this object to [AdsBootstrap.init] makes the package:
///
/// 1. request updated consent information on every bootstrap call,
/// 2. show the UMP form when Google says it is required, and
/// 3. allow ad loading only when UMP reports that ads may be requested.
///
/// Leaving this option `null` preserves the package's existing behavior and
/// does not call UMP. The host application remains responsible for choosing
/// the correct legal/privacy configuration and for providing any required
/// ATT disclosure and permission flow on iOS.
class AdsConsentOptions {
  /// Enables the built-in UMP integration when this option is supplied.
  final bool enabled;

  /// Whether the package should display the UMP form when required.
  final bool showFormIfRequired;

  /// Forwarded to UMP when the app knows the user is under the applicable age
  /// of consent. Leave it null when the app does not have that information.
  final bool? tagForUnderAgeOfConsent;

  /// Optional identifier used by UMP to synchronize consent between apps.
  final String? consentSyncId;

  /// Optional UMP debug geography for test devices.
  final AdsConsentDebugGeography? debugGeography;

  /// UMP debug device identifiers. Do not ship these as production behavior.
  final List<String> testDeviceIds;

  /// Receives recoverable UMP errors. The package still checks cached consent
  /// after an update/form error, so an offline user with valid prior consent
  /// is not unnecessarily blocked.
  final void Function(Object error)? onError;

  const AdsConsentOptions({
    this.enabled = true,
    this.showFormIfRequired = true,
    this.tagForUnderAgeOfConsent,
    this.consentSyncId,
    this.debugGeography,
    this.testDeviceIds = const <String>[],
    this.onError,
  });

  /// Explicitly disables the optional UMP integration.
  const AdsConsentOptions.disabled()
    : enabled = false,
      showFormIfRequired = false,
      tagForUnderAgeOfConsent = null,
      consentSyncId = null,
      debugGeography = null,
      testDeviceIds = const <String>[],
      onError = null;
}

/// The age treatment applied to future ad requests.
///
/// Set this only when the publisher has a reliable basis and authorization to
/// classify the user/app. Google recommends using age treatment instead of the
/// deprecated child-directed flags.
enum AdsAgeTreatment { unspecified, child, teen }

/// Maximum ad content rating allowed for future ad requests.
enum AdsMaxAdContentRating { unspecified, g, pg, t, ma }

/// Optional global request restrictions for the Google Mobile Ads SDK.
///
/// This maps to Google's [RequestConfiguration]. The default values are null,
/// so constructing an empty policy is a no-op. Test device IDs are useful for
/// development only and should never be populated in a release build.
class AdsPolicyOptions {
  final AdsAgeTreatment? ageTreatment;
  final AdsMaxAdContentRating? maxAdContentRating;
  final List<String>? testDeviceIds;

  const AdsPolicyOptions({
    this.ageTreatment,
    this.maxAdContentRating,
    this.testDeviceIds,
  });

  RequestConfiguration toRequestConfiguration() => RequestConfiguration(
    ageRestrictedTreatment: switch (ageTreatment) {
      null => null,
      AdsAgeTreatment.unspecified => AgeRestrictedTreatment.unspecified,
      AdsAgeTreatment.child => AgeRestrictedTreatment.child,
      AdsAgeTreatment.teen => AgeRestrictedTreatment.teen,
    },
    maxAdContentRating: switch (maxAdContentRating) {
      null => null,
      AdsMaxAdContentRating.unspecified => MaxAdContentRating.unspecified,
      AdsMaxAdContentRating.g => MaxAdContentRating.g,
      AdsMaxAdContentRating.pg => MaxAdContentRating.pg,
      AdsMaxAdContentRating.t => MaxAdContentRating.t,
      AdsMaxAdContentRating.ma => MaxAdContentRating.ma,
    },
    testDeviceIds: testDeviceIds,
  );
}

/// Small abstraction around UMP so consent decisions are testable without a
/// platform channel. Most applications never need to implement this type.
abstract interface class AdsConsentClient {
  Future<void> requestConsentInfoUpdate(AdsConsentOptions options);

  Future<void> loadAndShowConsentFormIfRequired();

  Future<AdsConsentStatus> getConsentStatus();

  Future<bool> canRequestAds();

  Future<bool> isPrivacyOptionsRequired();

  Future<void> showPrivacyOptionsForm();
}

/// UMP-backed implementation used by [AdsConsentManager].
class GoogleAdsConsentClient implements AdsConsentClient {
  final ConsentInformation _consentInformation;

  GoogleAdsConsentClient({ConsentInformation? consentInformation})
    : _consentInformation =
          consentInformation ?? ConsentInformation.instance;

  @override
  Future<void> requestConsentInfoUpdate(AdsConsentOptions options) {
    final completer = Completer<void>();

    try {
      _consentInformation.requestConsentInfoUpdate(
        ConsentRequestParameters(
          tagForUnderAgeOfConsent: options.tagForUnderAgeOfConsent,
          consentSyncId: options.consentSyncId,
          consentDebugSettings:
              options.debugGeography == null && options.testDeviceIds.isEmpty
              ? null
              : ConsentDebugSettings(
                  debugGeography: switch (options.debugGeography) {
                    null => DebugGeography.debugGeographyDisabled,
                    AdsConsentDebugGeography.disabled =>
                      DebugGeography.debugGeographyDisabled,
                    AdsConsentDebugGeography.eea =>
                      DebugGeography.debugGeographyEea,
                    AdsConsentDebugGeography.regulatedUsState =>
                      DebugGeography.debugGeographyRegulatedUsState,
                    AdsConsentDebugGeography.other =>
                      DebugGeography.debugGeographyOther,
                  },
                  testIdentifiers: options.testDeviceIds,
                ),
        ),
        () {
          if (!completer.isCompleted) completer.complete();
        },
        (error) {
          if (!completer.isCompleted) {
            completer.completeError(
              AdsConsentException('${error.errorCode}: ${error.message}'),
            );
          }
        },
      );
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    return completer.future;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();

    try {
      ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (completer.isCompleted) return;
        if (error == null) {
          completer.complete();
        } else {
          completer.completeError(
            AdsConsentException('${error.errorCode}: ${error.message}'),
          );
        }
      });
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    return completer.future;
  }

  @override
  Future<AdsConsentStatus> getConsentStatus() async {
    return switch (await _consentInformation.getConsentStatus()) {
      ConsentStatus.unknown => AdsConsentStatus.unknown,
      ConsentStatus.required => AdsConsentStatus.required,
      ConsentStatus.obtained => AdsConsentStatus.obtained,
      ConsentStatus.notRequired => AdsConsentStatus.notRequired,
    };
  }

  @override
  Future<bool> canRequestAds() => _consentInformation.canRequestAds();

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    return (await _consentInformation.getPrivacyOptionsRequirementStatus()) ==
        PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();

    try {
      ConsentForm.showPrivacyOptionsForm((error) {
        if (completer.isCompleted) return;
        if (error == null) {
          completer.complete();
        } else {
          completer.completeError(
            AdsConsentException('${error.errorCode}: ${error.message}'),
          );
        }
      });
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    return completer.future;
  }
}

/// Error raised by the package's UMP adapter.
class AdsConsentException implements Exception {
  final String message;

  const AdsConsentException(this.message);

  @override
  String toString() => 'AdsConsentException: $message';
}

/// Coordinates UMP and exposes the safe decision used by [AdsService].
class AdsConsentManager {
  final AdsConsentClient _client;

  AdsConsentManager({AdsConsentClient? client})
    : _client = client ?? GoogleAdsConsentClient();

  AdsConsentStatus _status = AdsConsentStatus.unknown;
  bool _canRequestAds = false;
  bool _enabled = false;
  bool _initialized = false;
  void Function(Object error)? _onError;

  AdsConsentStatus get status => _status;
  bool get isInitialized => _initialized;
  bool get isEnabled => _enabled;

  /// Updates UMP and returns whether ad requests are currently permitted.
  ///
  /// An update/form failure does not immediately revoke a previously cached
  /// decision. The cached [canRequestAds] value is checked afterwards. If UMP
  /// cannot confirm that ads may be requested, this returns false.
  Future<bool> requestConsent(AdsConsentOptions options) async {
    _enabled = options.enabled;
    _onError = options.onError;

    if (!options.enabled) {
      _initialized = true;
      _status = AdsConsentStatus.notRequired;
      _canRequestAds = true;
      return true;
    }

    try {
      await _client.requestConsentInfoUpdate(options);
      if (options.showFormIfRequired) {
        await _client.loadAndShowConsentFormIfRequired();
      }
    } catch (error) {
      _reportError(error);
    }

    _initialized = true;
    await _refreshCachedDecision();
    return _canRequestAds;
  }

  /// Returns the current UMP ad-request decision.
  Future<bool> canRequestAds() async {
    if (!_enabled) return true;
    if (!_initialized) return false;
    await _refreshCachedDecision();
    return _canRequestAds;
  }

  /// Whether Google requires a visible privacy-options entry point.
  Future<bool> isPrivacyOptionsRequired() async {
    if (!_enabled || !_initialized) return false;
    try {
      return await _client.isPrivacyOptionsRequired();
    } catch (error) {
      _reportError(error);
      return false;
    }
  }

  /// Shows Google's privacy-options form and refreshes the ad-request gate.
  ///
  /// Call this from a visible settings/privacy action when
  /// [isPrivacyOptionsRequired] is true.
  Future<bool> showPrivacyOptions() async {
    if (!_enabled || !_initialized) return false;

    try {
      await _client.showPrivacyOptionsForm();
    } catch (error) {
      _reportError(error);
    }

    await _refreshCachedDecision();
    return _canRequestAds;
  }

  Future<void> _refreshCachedDecision() async {
    try {
      _status = await _client.getConsentStatus();
    } catch (error) {
      _status = AdsConsentStatus.unknown;
      _reportError(error);
    }

    try {
      _canRequestAds = await _client.canRequestAds();
    } catch (error) {
      _canRequestAds = false;
      _reportError(error);
    }
  }

  void _reportError(Object error) {
    dPrint('⚠️ AdsConsent: $error');
    final onError = _onError;
    if (onError == null) return;

    try {
      onError(error);
    } catch (callbackError) {
      // Observability callbacks must never break startup or the privacy flow.
      dPrint('⚠️ AdsConsent: error callback failed: $callbackError');
    }
  }
}
