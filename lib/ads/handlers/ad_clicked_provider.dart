import 'package:flutter/material.dart';

/// Notifies listeners when an ad has been clicked during the current session.
///
/// This small state holder can be provided to widgets that need to react to
/// an ad click without coupling them to a specific ad handler.
class AdClickProvider extends ChangeNotifier {
  bool _hasClickedAd = false;

  /// Whether an ad click has been recorded.
  bool get hasClickedAd => _hasClickedAd;

  /// Records the first ad click and notifies listeners once.
  void markAdClicked() {
    if (!_hasClickedAd) {
      _hasClickedAd = true;
      notifyListeners();
    }
  }
}
