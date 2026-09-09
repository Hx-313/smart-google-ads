import 'package:flutter/material.dart';

import '../d_print.dart';

/// Global controller to manage banner ad visibility when dialogs open/close
class BannerAdController extends ChangeNotifier {
  static final BannerAdController _instance = BannerAdController._internal();
  factory BannerAdController() => _instance;
  BannerAdController._internal();

  bool _shouldHideBanner = false;
  int _dialogCount = 0;

  bool get shouldHideBanner => _shouldHideBanner;

  /// Call this when a dialog is opened
  void onDialogOpened() {
    _dialogCount++;
    if (!_shouldHideBanner) {
      _shouldHideBanner = true;
      notifyListeners();
      dPrint('🙈 Banner hidden: Dialog opened (count: $_dialogCount)');
    }
  }

  /// Call this when a dialog is closed
  void onDialogClosed() {
    _dialogCount = (_dialogCount - 1).clamp(0, 999);
    if (_dialogCount == 0 && _shouldHideBanner) {
      _shouldHideBanner = false;
      notifyListeners();
      dPrint('👁️ Banner shown: All dialogs closed');
    }
  }

  /// Reset the state (useful for testing)
  void reset() {
    _dialogCount = 0;
    _shouldHideBanner = false;
    notifyListeners();
  }
}
