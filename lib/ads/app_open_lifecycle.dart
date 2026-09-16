import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Coordinates app-open handling with the Mobile Ads plugin's app-state
/// stream. The injected stream is intended for deterministic unit tests.
class AppOpenLifecycleCoordinator {
  final Stream<AppState>? appStateStream;
  final void Function() onForeground;

  StreamSubscription<AppState>? _subscription;
  Future<void>? _startFuture;
  bool _disposed = false;
  bool _defaultListenerStarted = false;
  bool _defaultListenerStopped = false;

  AppOpenLifecycleCoordinator({
    required this.onForeground,
    this.appStateStream,
  });

  /// Starts listening once. The plugin listener is started before subscribing
  /// to its stream so the first state transition is not missed.
  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (_disposed) return;

    if (appStateStream == null) {
      await AppStateEventNotifier.startListening();
      _defaultListenerStarted = true;
    }

    if (_disposed) {
      await _stopDefaultListener();
      return;
    }

    _subscription = (appStateStream ?? AppStateEventNotifier.appStateStream)
        .where((state) => state == AppState.foreground)
        .listen((_) => onForeground());
  }

  /// Stops the subscription and, for the default stream, the plugin listener.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _stopDefaultListener();
  }

  Future<void> _stopDefaultListener() async {
    if (!_defaultListenerStarted || _defaultListenerStopped) return;
    _defaultListenerStopped = true;
    await AppStateEventNotifier.stopListening();
  }
}

/// Suppresses the first foreground opportunity after ads become available.
class AppOpenForegroundGate {
  final int skippedForegrounds;
  int _remaining;

  AppOpenForegroundGate({this.skippedForegrounds = 1})
    : assert(skippedForegrounds >= 0),
      _remaining = skippedForegrounds;

  bool shouldShow(AppState state) {
    if (state != AppState.foreground) return false;
    if (_remaining == 0) return true;
    _remaining--;
    return false;
  }

  void reset() => _remaining = skippedForegrounds;
}
