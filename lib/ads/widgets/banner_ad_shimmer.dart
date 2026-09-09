import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A theme-aware shimmer loading skeleton for banner ads.
///
/// Complies with Google AdMob policies and CLS prevention guidelines by
/// reserving the banner footprint while the ad is loading.
class BannerAdShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const BannerAdShimmer({
    super.key,
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final containerBg =
        isDark ? const Color(0xFF1E1F22) : const Color(0xFFF7F8FA);
    final containerBorder =
        isDark ? const Color(0xFF2E3035) : const Color(0xFFE5E7EB);

    final effectiveHeight = height ?? 56.0;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(6.0);

    // Calculate responsive icon and pill dimensions based on available height
    final iconDimension = (effectiveHeight - 16.0).clamp(24.0, 36.0);
    final buttonHeight = (effectiveHeight * 0.42).clamp(18.0, 24.0);

    return Container(
      width: width ?? double.infinity,
      height: effectiveHeight,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: containerBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ad icon placeholder
                Container(
                  width: iconDimension,
                  height: iconDimension,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                ),
                const SizedBox(width: 10.0),
                // Text lines placeholder
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 9.0,
                        width: double.infinity,
                        margin: const EdgeInsets.only(right: 24.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                      ),
                      const SizedBox(height: 5.0),
                      Container(
                        height: 7.0,
                        width: 70.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10.0),
                // Call-to-action pill placeholder
                Container(
                  width: 48.0,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(buttonHeight / 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
