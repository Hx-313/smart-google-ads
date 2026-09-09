import 'dart:async';
import 'dart:math';

import 'ads_config.dart';
import 'd_print.dart';

typedef RetryCallback = Future<bool> Function();

class AdsRetryManager {
  final AdsConfig config;
  AdsRetryManager(this.config);

  /// Retries [loadAd] with exponential backoff + jitter.
  /// Returns true on first successful attempt.
  ///
  /// Backoff: 2s → 4s → 8s → 16s (with ±500ms jitter)
  Future<bool> retry(
    RetryCallback loadAd, {
    String? label,
    int? maxAttempts,
  }) async {
    final max = maxAttempts ?? config.maxRetryAttempts;

    for (int attempt = 0; attempt <= max; attempt++) {
      try {
        final success = await loadAd();
        if (success) {
          if (attempt > 0) {
            dPrint('✅ $label: Loaded on retry #$attempt');
          }
          return true;
        }
      } catch (e) {
        dPrint('❌ $label: Attempt #$attempt exception: $e');
      }

      if (attempt < max) {
        // Exponential backoff: 2^attempt * base delay + jitter
        final backoff = config.retryBaseDelay * pow(2, attempt);
        final jitter = Duration(milliseconds: Random().nextInt(500));
        final delay = backoff + jitter;

        dPrint(
          '⏰ $label: Retry ${attempt + 1}/$max in ${delay.inMilliseconds}ms',
        );
        await Future.delayed(delay);
      }
    }

    dPrint('🛑 $label: All $max retries exhausted');
    return false;
  }
}
