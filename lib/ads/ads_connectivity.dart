import 'dart:async';
import 'dart:io';

import 'd_print.dart';

/// Connectivity checker with periodic recheck.
///
/// YOUR OLD PROBLEM: One-way latch permanently blocked ads if user
/// opened app offline. Even 30 seconds in an elevator = zero ads for
/// entire session.
///
/// NEW DESIGN:
/// - First check: real DNS lookup
/// - If offline: rechecks every [recheckInterval] (default 2 min)
/// - If online: caches for [recheckInterval] then rechecks
/// - No permanent latch — recovers from temporary offline
class AdsConnectivity {
  static bool _lastResult = false;
  static DateTime? _lastCheckTime;
  static bool _isChecking = false;
  static Duration _recheckInterval = const Duration(minutes: 2);

  static void configure({Duration? recheckInterval}) {
    if (recheckInterval != null) _recheckInterval = recheckInterval;
  }

  static bool get isOnline => _lastResult;

  /// Returns true if online. Caches result for [_recheckInterval].
  static Future<bool> check() async {
    // Return cached result if recent enough
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _recheckInterval) {
      return _lastResult;
    }

    // Prevent concurrent checks
    if (_isChecking) {
      // Wait for ongoing check (max 6s)
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_isChecking) return _lastResult;
      }
      return _lastResult;
    }

    _isChecking = true;

    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      _lastResult = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      _lastResult = false;
    } on TimeoutException {
      _lastResult = false;
    } catch (_) {
      _lastResult = false;
    } finally {
      _lastCheckTime = DateTime.now();
      _isChecking = false;
    }

    dPrint(
      '🌐 AdsConnectivity: ${_lastResult ? "Online ✅" : "Offline ❌"} '
      '(next check in ${_recheckInterval.inSeconds}s)',
    );

    return _lastResult;
  }

  /// Force immediate recheck (call after network change event)
  static Future<bool> forceCheck() {
    _lastCheckTime = null;
    return check();
  }

  static void reset() {
    _lastResult = false;
    _lastCheckTime = null;
    _isChecking = false;
  }
}
