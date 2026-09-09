import 'package:flutter/material.dart';
import 'package:smart_google_ads/smart_google_ads.dart';

// These are Google's test ad-unit IDs. Keep test IDs in this example.
const exampleAdUnitIds = AdsAdUnitIds(
  banner: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/6300978111',
    ios: 'ca-app-pub-3940256099942544/2934735716',
  ),
  interstitial: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/1033173712',
    ios: 'ca-app-pub-3940256099942544/4411468910',
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdsBootstrap.init(
    adUnitIds: exampleAdUnitIds,
    useRemoteConfig: false,
    adsEnabled: true,
    bannerEnabled: true,
    interstitialEnabled: true,
    interstitialAfter: 3,
    rewardedEnabled: false,
    nativeEnabled: false,
    appOpenEnabled: false,
    directInterstitialEnabled: false,
    // Remove this line only if the host app owns an equivalent consent flow.
    consent: const AdsConsentOptions(),
  );

  runApp(const SmartGoogleAdsExampleApp());
}

class SmartGoogleAdsExampleApp extends StatelessWidget {
  const SmartGoogleAdsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smart_google_ads example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = AdsService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('smart_google_ads')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Local mode is enabled. Tap the visit button three times to '
            'reach the interstitial threshold.',
          ),
          const SizedBox(height: 16),
          const SmartBannerAdWidget(padding: EdgeInsets.only(bottom: 16)),
          FilledButton(
            onPressed: () {
              ads.onScreenVisit();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Visits until next opportunity: '
                    '${ads.visitsUntilNextAd}',
                  ),
                ),
              );
            },
            child: const Text('Record screen visit'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final shown = await ads.showInterstitialNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(shown ? 'Ad shown' : 'Ad not ready')),
              );
            },
            child: const Text('Show interstitial now (bypasses count)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              SmartDialog.showMaterialDialog<void>(
                context: context,
                dialog: AlertDialog(
                  title: const Text('SmartDialog'),
                  content: const Text(
                    'The banner is hidden and app-open ads are blocked while '
                    'this dialog is visible.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Open SmartDialog'),
          ),
          FutureBuilder<bool>(
            future: AdsBootstrap.isPrivacyOptionsRequired(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return TextButton(
                onPressed: AdsBootstrap.showPrivacyOptions,
                child: const Text('Privacy options'),
              );
            },
          ),
        ],
      ),
    );
  }
}
