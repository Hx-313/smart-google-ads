import 'package:flutter/material.dart';

/// A theme-aware animated loading skeleton for banner ads.
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
  Widget build(BuildContext context) => _AnimatedBannerAdShimmer(
    width: width,
    height: height,
    margin: margin,
    padding: padding,
    borderRadius: borderRadius,
  );
}

class _AnimatedBannerAdShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const _AnimatedBannerAdShimmer({
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.borderRadius,
  });

  @override
  State<_AnimatedBannerAdShimmer> createState() =>
      _AnimatedBannerAdShimmerState();
}

class _AnimatedBannerAdShimmerState extends State<_AnimatedBannerAdShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF35383F)
        : const Color(0xFFE3E7ED);
    final highlightColor = isDark
        ? const Color(0xFF5A606B)
        : const Color(0xFFF9FAFC);
    final containerBg = isDark
        ? const Color(0xFF1E1F22)
        : const Color(0xFFF7F8FA);
    final containerBorder = isDark
        ? const Color(0xFF2E3035)
        : const Color(0xFFE5E7EB);

    final effectiveHeight = (widget.height ?? 56.0)
        .clamp(0.0, double.infinity)
        .toDouble();
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(6.0);

    return Container(
      width: widget.width ?? double.infinity,
      height: effectiveHeight,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: effectiveBorderRadius,
        border: Border.all(color: containerBorder, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final gradient = LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlidingShimmerTransform(
                _animationController.value * 2 - 1,
              ),
            );

            return ShaderMask(
              shaderCallback: gradient.createShader,
              blendMode: BlendMode.srcATop,
              child: child,
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : effectiveHeight;
              final verticalInset = (availableHeight / 8)
                  .clamp(0.0, 4.0)
                  .toDouble();
              final innerHeight = (availableHeight - verticalInset * 2)
                  .clamp(0.0, availableHeight)
                  .toDouble();
              final iconDimension = innerHeight
                  .clamp(0.0, 36.0)
                  .toDouble();
              final primaryLineHeight = (innerHeight * 0.3)
                  .clamp(0.0, 9.0)
                  .toDouble();
              final secondaryLineHeight = (innerHeight * 0.25)
                  .clamp(0.0, 7.0)
                  .toDouble();
              final lineGap = (innerHeight -
                      primaryLineHeight -
                      secondaryLineHeight)
                  .clamp(0.0, 5.0)
                  .toDouble();
              final buttonHeight = (innerHeight * 0.42)
                  .clamp(0.0, 24.0)
                  .toDouble();

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: verticalInset,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: iconDimension,
                      height: iconDimension,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: primaryLineHeight,
                            width: double.infinity,
                            margin: const EdgeInsets.only(right: 24.0),
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                          ),
                          SizedBox(height: lineGap),
                          Container(
                            height: secondaryLineHeight,
                            width: 70.0,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Container(
                      width: 48.0,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(buttonHeight / 2),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlidingShimmerTransform extends GradientTransform {
  final double slide;

  const _SlidingShimmerTransform(this.slide);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}
