# smart_google_ads

An ad-ready Flutter package built on `google_mobile_ads`. It provides one
bootstrap entry point for Mobile Ads, optional Firebase Remote Config flags,
platform-aware ad unit IDs, safe preload/retry behavior, app-open suppression,
adaptive banners, native templates, rewarded ads, and ad-aware dialogs.
It also offers opt-in Google UMP consent handling and modern age/content
request restrictions without changing legacy initialization behavior.

## Step 1 — Install the package

Install the published package from pub.dev:

```bash
flutter pub add smart_google_ads
```

If you enable Firebase Remote Config, also add Firebase Core:

```bash
flutter pub add firebase_core
```

The host app must still complete the normal platform setup for
`google_mobile_ads`, including the AdMob application ID in Android and iOS
configuration. If Remote Config is enabled, the host app must also initialize
Firebase before calling the bootstrap:

```dart
await Firebase.initializeApp();
```

The package does not read the host app's `.env` file and does not own Firebase
initialization. IDs are passed explicitly, which makes the package portable
and avoids hidden environment dependencies.

## Steps 2–8 — Complete the host-app setup

Complete this setup once in the Flutter app that uses the package. The
package can initialize the Mobile Ads SDK and load ad units, but only the host
app can provide its platform configuration files. Follow the steps in order;
Step 5A and Step 5B are alternatives, so choose only one Remote Config mode.

### Step 2 — Create AdMob app IDs and ad-unit IDs

In AdMob, create an app for every platform you support and create the ad units
you will use. There are two different kinds of IDs:

- The **AdMob app ID** contains a tilde (`~`) and is placed in Android's
  manifest and iOS's `Info.plist`.
- An **ad-unit ID** contains a slash (`/`) and is passed to
  `PlatformAdIds` in the Dart bootstrap configuration.

Do not put an ad-unit ID in the manifest or an app ID in `PlatformAdIds`.

### Step 3 — Configure Android Gradle and manifest

The current dependencies require an Android app with `minSdk` 24 or higher.
Use `compileSdk` 36 or higher. In
`android/app/build.gradle.kts` (new Flutter projects), make sure the values
are at least:

```kotlin
android {
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }
}
```

For an older Groovy project, the equivalent is:

```groovy
android {
    compileSdkVersion 36

    defaultConfig {
        minSdkVersion 24
    }
}
```

If your project already has higher values, keep the higher values. Do not add
another Google Mobile Ads Gradle dependency manually; `google_mobile_ads`
provides it through the Flutter plugin.

Open `android/app/src/main/AndroidManifest.xml`. Add the internet permission
under `<manifest>` and the AdMob **app ID** inside `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="your_app_name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- Android AdMob APP ID: contains ~, not / -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy" />

        <!-- Keep the rest of your existing application entries. -->
    </application>
</manifest>
```

Use Google's Android test app ID while testing:
`ca-app-pub-3940256099942544~3347511713`.

### Step 4 — Configure iOS Runner and Info.plist

The current Google Mobile Ads SDK requires iOS 13.0 or higher. In
`ios/Podfile`, use:

```ruby
platform :ios, '13.0'
```

Open `ios/Runner/Info.plist` and add the AdMob **app ID** inside the top-level
`<dict>`:

```xml
<!-- iOS AdMob APP ID: contains ~, not / -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

No AppDelegate or Runner Dart code is required for Mobile Ads initialization;
`AdsBootstrap.init` calls it for you. If your app separately requests App
Tracking Transparency permission, add your own
`NSUserTrackingUsageDescription` and request consent according to your
privacy flow. This package does not request ATT permission automatically.

### Step 5 — Create the Dart ad-unit configuration

Define the ad-unit IDs once in Dart. Use an ad-unit ID containing `/`, not the
AdMob app ID containing `~`. Each ad type is optional. This example uses
Google's platform-specific test IDs in debug builds:

```dart
import 'package:smart_google_ads/smart_google_ads.dart';

const adUnitIds = AdsAdUnitIds(
  banner: PlatformAdIds(
    android: 'ca-app-pub-xxx/banner-android',
    ios: 'ca-app-pub-xxx/banner-ios',
    debugAndroid: 'ca-app-pub-3940256099942544/6300978111',
    debugIos: 'ca-app-pub-3940256099942544/2934735716',
  ),
  interstitial: PlatformAdIds(
    android: 'ca-app-pub-xxx/interstitial-android',
    ios: 'ca-app-pub-xxx/interstitial-ios',
    debugAndroid: 'ca-app-pub-3940256099942544/1033173712',
    debugIos: 'ca-app-pub-3940256099942544/4411468910',
  ),
  rewarded: PlatformAdIds(
    android: 'ca-app-pub-xxx/rewarded-android',
    ios: 'ca-app-pub-xxx/rewarded-ios',
    debugAndroid: 'ca-app-pub-3940256099942544/5224354917',
    debugIos: 'ca-app-pub-3940256099942544/1712485313',
  ),
);
```

Replace the `xxx` values with your production ad-unit IDs. The debug fields
are used only in debug builds; release builds use the normal Android/iOS IDs.

### Step 6A — Configure Firebase Remote Config (optional)

Skip this section when using `useRemoteConfig: false`.

From the host Flutter app's directory:

```bash
flutter pub add firebase_core
dart pub global activate flutterfire_cli
flutterfire configure
```

`flutterfire configure` creates `lib/firebase_options.dart` and configures the
selected Android/iOS Firebase apps. Initialize Firebase before the ads
bootstrap:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_google_ads/smart_google_ads.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AdsBootstrap.init(
    adUnitIds: adUnitIds,
    useRemoteConfig: true,
    consent: const AdsConsentOptions(),
  );

  runApp(const MyApp());
}
```

The package owns Remote Config defaults, fetching, activation, and fallback.
The host app owns the Firebase project and its `GoogleService-Info.plist` /
`google-services.json` configuration generated by FlutterFire.

### Step 6B — Use local controls without Remote Config

This is the simplest setup. Do not add Firebase for ads. Leave
`useRemoteConfig` as `false` (its default), and control the package from the
boolean and count arguments passed to `AdsBootstrap.init`.

```dart
await AdsBootstrap.init(
  adUnitIds: adUnitIds,
  useRemoteConfig: false,
  adsEnabled: true,
  bannerEnabled: true,
  interstitialEnabled: true,
  interstitialAfter: 3,
  rewardedEnabled: true,
  nativeEnabled: false,
  appOpenEnabled: false,
  directInterstitialEnabled: false,
);
```

The local controls mean:

| Argument | `true` | `false` |
| --- | --- | --- |
| `adsEnabled` | Allows every configured ad type. | Turns off all ads. |
| `bannerEnabled` | Allows banners when a banner ID exists. | Disables banners. |
| `interstitialEnabled` | Allows counted interstitials. | Disables counted interstitials. |
| `rewardedEnabled` | Allows rewarded ads. | Disables rewarded ads. |
| `nativeEnabled` | Allows native ads when a native ID exists. | Disables native ads. |
| `appOpenEnabled` | Allows app-open ads. | Disables app-open ads. |
| `directInterstitialEnabled` | Allows direct/splash interstitials. | Disables direct interstitials. |

An explicit `true` cannot create an ad without an ID. If an ID is missing for
the current platform, that ad type remains unavailable. When a flag is
omitted, most types automatically enable if an ID is available; native ads are
opt-in and default to disabled.

`interstitialAfter` controls only the frequency-based APIs:

```dart
final ads = AdsService.instance;

ads.onScreenVisit();
// The third visit is eligible when interstitialAfter is 3 and an ad is ready.

ads.showBeforeNavigation(() {
  Navigator.of(context).push(nextRoute);
});
```

The ad must already be loaded. If it is not ready, navigation continues and
the package keeps loading it in the background. `showInterstitialNow()` and
`showDirect()` intentionally bypass the visit count. Set
`interstitialEnabled: false` to disable counted interstitials, or
`adsEnabled: false` to disable everything.

These local values are selected when the package starts. To change them for
all users, update the code and publish an app update. Use Remote Config when
you need to change the values without publishing a new app version.

### Step 7 — Configure privacy, consent, and restrictions

The package includes an optional integration with Google's User Messaging
Platform (UMP). It requests fresh consent information, shows the UMP form when
required, and blocks ad loading until UMP says that ad requests are allowed.
This is opt-in so existing apps that omit `consent` keep their current
behavior.

Before release, create and publish the applicable message in AdMob's
**Privacy & messaging** area. The package displays Google's configured UMP
message; it cannot create or publish that message for the host app.

For a new app, use the consent-aware bootstrap and apply only the restrictions
that match your verified audience and legal/privacy decisions:

```dart
await AdsBootstrap.init(
  adUnitIds: adUnitIds,
  consent: AdsConsentOptions(
    // Optional: development-only UMP diagnostics.
    // debugGeography: AdsConsentDebugGeography.eea,
    // testDeviceIds: ['YOUR_UMP_TEST_DEVICE_ID'],
    onError: (error) {
      dPrint('Consent error: $error');
    },
  ),
  policy: const AdsPolicyOptions(
    maxAdContentRating: AdsMaxAdContentRating.pg,
    // Set child or teen treatment only when it is accurate and authorized.
    ageTreatment: AdsAgeTreatment.unspecified,
  ),
);
```

`AdsPolicyOptions` applies Google's global request configuration to future ads.
It uses the current `ageRestrictedTreatment` API and does not use deprecated
child-directed flags. `testDeviceIds` and `debugGeography` are for development
only; remove them from release configuration.

If Google says a privacy-options entry point is required, expose it from a
visible privacy/settings screen:

```dart
FutureBuilder<bool>(
  future: AdsBootstrap.isPrivacyOptionsRequired(),
  builder: (context, snapshot) {
    if (snapshot.data != true) return const SizedBox.shrink();
    return TextButton(
      onPressed: () {
        AdsBootstrap.showPrivacyOptions();
      },
      child: const Text('Privacy options'),
    );
  },
);
```

`AdsBootstrap.showPrivacyOptions()` refreshes the package's ad gate after the
user saves a new choice. Consent errors are reported through `onError`; a
previously stored valid decision can continue to work offline, while an
unknown decision blocks ad requests.

The host app is still responsible for its privacy policy, age/audience
classification, regional publisher requirements, Google consent-message
configuration, and any iOS App Tracking Transparency (ATT) disclosure and
permission flow. The package does not silently request ATT, make legal
decisions, or enable Firebase/Google Consent Mode on the host's behalf.

### Step 8 — Final setup checklist

- [ ] `flutter pub add smart_google_ads` completed.
- [ ] AdMob app ID added to Android `AndroidManifest.xml`.
- [ ] AdMob app ID added to iOS `Runner/Info.plist`.
- [ ] Android `minSdk` is at least 24 and iOS deployment target is at least
  13.0.
- [ ] `PlatformAdIds` contains ad-unit IDs, not app IDs.
- [ ] Google test IDs are used during development.
- [ ] Firebase is initialized before `useRemoteConfig: true`.
- [ ] `consent: AdsConsentOptions()` is enabled for the recommended UMP flow,
      unless the host app intentionally owns an equivalent consent flow.
- [ ] `policy: AdsPolicyOptions(...)` matches the verified audience and content
      rating requirements.
- [ ] A visible privacy-options entry point is provided when UMP requires it.
- [ ] `AdsBootstrap.init` runs before the first ad widget is built.

## Step 9 — Remote Config controls

Remote Config is optional. The package first builds a local fallback from the
IDs and local options, then overlays remote values. If Firebase, the network,
or a key is unavailable, the fallback remains active.

The standard keys are:

| Package key | Default Remote Config key | Type |
| --- | --- | --- |
| `AdRemoteKeys.adsEnabled` | `ads_enabled` | bool |
| `AdRemoteKeys.banner` | `isBannerShow` | bool |
| `AdRemoteKeys.interstitial` | `isIntersitialShow` | bool |
| `AdRemoteKeys.rewarded` | `rewardedEnabled` | bool |
| `AdRemoteKeys.native` | `isNativeShow` | bool |
| `AdRemoteKeys.appOpen` | `isAppopenShow` | bool |
| `AdRemoteKeys.directInterstitial` | `isSplashIntersitialShow` | bool |
| `AdRemoteKeys.adsCount` | `adsCount` | int |

For example, Remote Config values of `ads_enabled = true`,
`isBannerShow = true`, `isIntersitialShow = true`, and `adsCount = 3` enable
banners, enable counted interstitials, and show an interstitial opportunity
after three visits. Setting any boolean to `false` disables that feature;
setting `ads_enabled` to `false` disables all ad types. These dashboard values
are only used when Remote Config is enabled; otherwise use the local bootstrap
arguments described in Step 6B.

For a project with different names, use the typed options:

```dart
await AdsBootstrap.init(
  adUnitIds: adUnitIds,
  remoteConfig: AdsRemoteConfigOptions(
    keys: {
      AdRemoteKeys.adsEnabled: 'ads_enabled',
      AdRemoteKeys.banner: 'show_banner',
      AdRemoteKeys.interstitial: 'show_interstitial',
      AdRemoteKeys.adsCount: 'interstitial_frequency',
    },
    onFetched: (remoteConfig) {
      // Read app-specific Remote Config values here if needed.
    },
  ),
);
```

The host app must have a configured Firebase project. Remote Config controls
whether an already-configured ad type is enabled; it cannot create a missing
ad unit ID.

## Step 10 — Show ads

```dart
final ads = AdsService.instance;

// Count a visit and show only when an already-loaded interstitial is ready.
ads.onScreenVisit();

// For navigation-gated flows; navigation always continues if no ad is ready.
ads.showBeforeNavigation(() => Navigator.of(context).push(nextRoute));

// Immediate interstitial; returns false when unavailable.
final shown = await ads.showInterstitialNow();

// Rewarded ad; premium users receive the reward callback without an ad.
await ads.showRewarded(
  onUserEarnedReward: () async => grantReward(),
);

// Splash/direct interstitial; navigation resumes when it is dismissed or skipped.
ads.showDirect(onResumeNavigation: () => openHome());
```

## Step 11 — Add smart widgets

Use the package widgets instead of constructing `BannerAd` or `AdWidget`
directly. They check initialization, premium status, Remote Config, IDs,
loading state, and banner visibility for you:

```dart
const SmartBannerAdWidget(
  padding: EdgeInsets.symmetric(vertical: 8),
  collapsible: true,
)
```

Native ads are opt-in because apps commonly need different placements:

```dart
const SmartNativeAdWidget(size: NativeTemplateSize.small)
```

## Step 12 — Use SmartDialog for modal UI

Do not call Flutter's `showDialog`, `showModalBottomSheet`, or
`showCupertinoDialog` directly when a banner can be on screen. Use
`SmartDialog` (or the `BuildContext` extensions) so the banner is hidden while
the modal is open and app-open ads are blocked during the modal flow. State is
restored even if the modal throws or is dismissed:

```dart
await SmartDialog.showMaterialDialog<void>(
  context: context,
  dialog: AlertDialog(
    title: const Text('Remove ads'),
    content: const Text('Upgrade to continue without advertising.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

await context.showSmartBottomSheet<void>(
  builder: (context) => const SizedBox(
    height: 240,
    child: Center(child: Text('Ad-aware bottom sheet')),
  ),
);
```

For camera, file picker, permission, share sheet, or another flow that can
temporarily background the app, use the app-open suppression API:

```dart
final file = await AdsService.instance.runWithoutAppOpen(
  () => filePicker.pickFiles(),
  reason: 'file_picker',
);
```

## Step 13 — Protect app-open flows

Use `skipNextAppOpen()` for one short external transition, or
`blockAppOpen(reason)`/`unblockAppOpen(reason)` for a named long-running flow.
`runWithoutAppOpen` is preferred because it guarantees cleanup and has a
safety timeout.

## Step 14 — Release checklist

- Use Google's test IDs during development and replace them with production
  IDs before release.
- Configure the AdMob application ID in the host app's Android/iOS setup.
- Initialize Firebase before using Remote Config.
- Never show an interstitial immediately on app launch or on every tap.
- Keep the `isProUser` callback cheap and synchronous; it may be called often.
- Reset the package only in tests or when intentionally rebuilding its global
  singleton: `AdsService.reset()`.

Official setup references:

- [Google Mobile Ads Flutter setup](https://developers.google.com/admob/flutter/quick-start)
- [Google UMP consent for Flutter](https://developers.google.com/admob/flutter/privacy)
- [Google ad-serving privacy modes](https://developers.google.com/admob/flutter/privacy/ad-serving-modes)
- [Google Mobile Ads targeting and age treatment](https://developers.google.com/admob/flutter/targeting)
- [Firebase setup for Flutter](https://firebase.google.com/docs/flutter/setup)
