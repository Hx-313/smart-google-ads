import 'package:flutter/material.dart';

import '../ads_service.dart';
import '../handlers/native_handler.dart';

class SmartNativeAdWidget extends StatefulWidget {
  final NativeTemplateSize size;
  final EdgeInsets margin;
  final bool silent; // 👈 If true, won't show loading spinner, just hides

  const SmartNativeAdWidget({
    super.key,
    this.size = NativeTemplateSize.small,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.silent = true, // 👈 Default to silent
  });

  @override
  State<SmartNativeAdWidget> createState() => _SmartNativeAdWidgetState();
}

class _SmartNativeAdWidgetState extends State<SmartNativeAdWidget> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() {
    final handler = AdsService.instance.nativeHandler;

    // If already loaded from preload, just show it
    if (handler?.isLoaded == true) {
      setState(() => _isLoaded = true);
    } else if (!widget.silent) {
      // If not silent, we trigger a manual load
      _loadNative();
    }
  }

  Future<void> _loadNative() async {
    if (!AdsService.instance.hasNative) return;
    // Try to load with 0 retries (don't hang the UI)
    final success = await AdsService.instance.loadNative(
      size: widget.size,
      maxAttempts: 0,
    );
    if (success && mounted) {
      setState(() => _isLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Requirement: "check if loaded show else not"
    // If not loaded, we return SizedBox.shrink() so the UI collapses
    if (!_isLoaded || AdsService.instance.nativeHandler?.ad == null) {
      return const SizedBox.shrink();
    }

    double height =
        MediaQuery.of(context).size.height *
        (widget.size == NativeTemplateSize.small ? 0.16 : 0.45);

    return Container(
      height: height,
      margin: widget.margin,
      width: double.infinity,
      child: AdsService.instance.nativeHandler!.widget,
    );
  }
}
