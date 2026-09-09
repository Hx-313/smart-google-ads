import 'package:flutter/foundation.dart';

/// Simply use dPrint('message') instead of debugPrint
void dPrint(Object? message) {
  if (kDebugMode) {
    debugPrint(message?.toString());
  }
}
