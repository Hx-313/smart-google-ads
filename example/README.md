# smart_google_ads example

This example demonstrates the package without Firebase Remote Config. It
uses Google's test ad-unit IDs and shows:

- local `true`/`false` ad controls;
- an interstitial opportunity after three visits;
- the Smart banner widget;
- SmartDialog; and
- the optional UMP privacy-options entry point.

From this directory, create the native runner files once and run the example:

```bash
flutter create .
flutter pub get
flutter run --dart-define=USE_NEXT_GEN_SDK=true
```

To verify the Android Next-Gen dependency selection, also run:

```bash
flutter build apk --debug --dart-define=USE_NEXT_GEN_SDK=true
```

The example omits `consent`: debug builds therefore skip the UMP gate for
Google test ads, while release builds enforce UMP. Pass an explicit
`AdsConsentOptions` value when testing UMP geography or device settings.

Before expecting ads to load, add the AdMob **app ID** to the generated
Android manifest and iOS `Info.plist` as described in the package root
README. The Dart code uses test ad units, so do not replace them with
production IDs while experimenting with this example.
