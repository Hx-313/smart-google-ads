import 'package:flutter/material.dart';

class AdClickProvider extends ChangeNotifier {
  bool _hasClickedAd = false;

  bool get hasClickedAd => _hasClickedAd;

  void markAdClicked() {
    if (!_hasClickedAd) {
      _hasClickedAd = true;
      notifyListeners();
    }
  }
}
