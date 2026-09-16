import 'package:flutter/material.dart';
import 'package:smart_google_ads/smart_google_ads.dart';

// Test Ad Unit IDs provided for Android & iOS fallbacks
const exampleAdUnitIds = AdsAdUnitIds(
  banner: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/9214589741',
    ios: 'ca-app-pub-3940256099942544/2934735716',
  ),
  interstitial: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/1033173712',
    ios: 'ca-app-pub-3940256099942544/4411468910',
  ),
  rewarded: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/5224354917',
    ios: 'ca-app-pub-3940256099942544/1712485313',
  ),
  native: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/2247696110',
    ios: 'ca-app-pub-3940256099942544/3986624511',
  ),
  appOpen: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/9257395921',
    ios: 'ca-app-pub-3940256099942544/5632435107',
  ),
  directInterstitial: PlatformAdIds(
    android: 'ca-app-pub-3940256099942544/3419835294',
    ios: 'ca-app-pub-3940256099942544/4411468910',
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdsBootstrap.init(
    adUnitIds: exampleAdUnitIds,
    adsEnabled: true,
    bannerEnabled: true,
    interstitialEnabled: true,
    interstitialAfter: 2,
    rewardedEnabled: true,
    nativeEnabled: true,
    appOpenEnabled: true,
    directInterstitialEnabled: true,
  );

  runApp(const SmartGoogleAdsExampleApp());
}

class SmartGoogleAdsExampleApp extends StatelessWidget {
  const SmartGoogleAdsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Google Ads Suite',
      theme: ThemeData(colorSchemeSeed: Colors.greenAccent, useMaterial3: true),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  int _rewardCount = 0;

  @override
  Widget build(BuildContext context) {
    final ads = AdsService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Google Ads Suite'), elevation: 2),
      body: SafeArea(
        child: Column(
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Adaptive Banner Ad',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    SmartBannerAdWidget(
                      padding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Adaptive Banner Ad ──
                  const SizedBox(height: 12),

                  // ── Native Ad ──
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. Native Ad (Small Template)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          SmartNativeAdWidget(
                            size: NativeTemplateSize.small,
                            silent: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Interstitial & Screen Visit Counter ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '3. Interstitial Ad Controls',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Visits until auto interstitial: ${ads.visitsUntilNextAd}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    ads.onScreenVisit();
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Visits until next ad: ${ads.visitsUntilNextAd}',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.touch_app),
                                  label: const Text('Record Visit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final shown = await ads
                                        .showInterstitialNow();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          shown
                                              ? 'Interstitial Shown!'
                                              : 'Interstitial Not Ready',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.fullscreen),
                                  label: const Text('Show Now'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Direct / Splash Interstitial ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '4. Direct (Splash) Interstitial',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              ads.showDirect(
                                onDismissed: () {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Direct Interstitial Dismissed',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                onResumeNavigation: () {
                                  dPrint(
                                    'Direct interstitial navigation resumed',
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.flash_on),
                            label: const Text('Show Direct Interstitial'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Rewarded Ad ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '5. Rewarded Ad',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Rewards Earned: $_rewardCount'),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                            ),
                            onPressed: () async {
                              final success = await ads.showRewarded(
                                onUserEarnedReward: () async {
                                  setState(() {
                                    _rewardCount++;
                                  });
                                },
                                onDismissed: () {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Rewarded Ad Closed. Total rewards: $_rewardCount',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Rewarded Ad Not Ready'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.card_giftcard),
                            label: const Text('Watch Rewarded Ad'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── App Open Ad ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '6. App Open Ad',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final shown = await ads.showAppOpen();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    shown
                                        ? 'App Open Ad Shown!'
                                        : 'App Open Ad Not Ready / Blocked',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Trigger App Open Ad'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── SmartDialog (App Open & Banner Suppressor) ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '7. SmartDialog Protection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              SmartDialog.showMaterialDialog<void>(
                                context: context,
                                dialog: AlertDialog(
                                  title: const Text('SmartDialog Active'),
                                  content: const Text(
                                    'Banner ads are automatically hidden and App Open ads '
                                    'are suppressed while this dialog is visible.',
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
                            icon: const Icon(Icons.security),
                            label: const Text('Open SmartDialog'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Privacy Options ──
                  FutureBuilder<bool>(
                    future: AdsBootstrap.isPrivacyOptionsRequired(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: AdsBootstrap.showPrivacyOptions,
                          icon: const Icon(Icons.privacy_tip),
                          label: const Text('Privacy Options (UMP)'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
