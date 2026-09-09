import 'dart:io';

class PlatformAdIds {
  final String android;
  final String ios;

  const PlatformAdIds({required this.android, required this.ios});

  String get current => Platform.isAndroid ? android : ios;

  /// Returns null if both platforms are empty
  bool get isEmpty => android.isEmpty && ios.isEmpty;
}

class PlatformRCKeys {
  final String android;
  final String ios;

  const PlatformRCKeys({required this.android, required this.ios});

  String get current => Platform.isAndroid ? android : ios;
}