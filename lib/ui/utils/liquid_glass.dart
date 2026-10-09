import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// A frosted "liquid glass" surface.
///
/// Inspired by the iOS 26 Liquid Glass look
/// (https://github.com/nikdelvin/liquid-glass): a translucent, blurred panel
/// with a soft edge highlight that refracts whatever sits behind it.
///
/// Place it on top of content (a colorful background or artwork) to obtain the
/// classic glassmorphism effect.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 22,
    this.radius = 0,
    this.padding,
    this.margin,
    this.tint,
    this.bordered = true,
    this.width,
    this.height,
    this.boxShadow,
    this.borderRadius,
  });

  /// The widget shown on top of the glass.
  final Widget child;

  /// Backdrop blur strength.
  final double blur;

  /// Corner radius (ignored when [borderRadius] is provided).
  final double radius;

  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Base tint of the glass. Defaults to white (frosted) / adapts to theme.
  final Color? tint;

  /// Draws the subtle 1px edge highlight.
  final bool bordered;

  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final baseTint = tint ?? Colors.white;
    final highlight = baseTint.withOpacity(isLight ? 0.42 : 0.24);
    final lowlight = baseTint.withOpacity(isLight ? 0.06 : 0.03);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 22,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [highlight, lowlight],
              ),
              border: bordered
                  ? Border.all(
                      color: baseTint.withOpacity(isLight ? 0.45 : 0.22),
                      width: 1.2)
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A static, softly blurred mesh-gradient background used behind the glass.
///
/// Colors are derived from the current theme primary color so the glass keeps
/// matching the dynamic theme that follows the album art.
class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key, this.baseColor, this.child});

  final Color? baseColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = baseColor ?? theme.primaryColor;
    final isLight = theme.brightness == Brightness.light;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BlobPainter(base: base, light: isLight),
        child: child,
      ),
    );
  }
}

class _Blob {
  const _Blob(this.hueShift, this.x, this.y, this.radiusFactor);
  final double hueShift;
  final double x;
  final double y;
  final double radiusFactor;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.base, required this.light});

  final Color base;
  final bool light;

  static const List<_Blob> _blobs = [
    _Blob(0, 0.16, 0.13, 0.72),
    _Blob(58, 0.87, 0.19, 0.62),
    _Blob(128, 0.50, 0.46, 0.68),
    _Blob(-48, 0.21, 0.85, 0.74),
    _Blob(176, 0.83, 0.79, 0.60),
    _Blob(268, 0.44, 0.09, 0.56),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Vivid base gradient (stands in for the colourful background image used by
    // the original web reference).
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: light
            ? const [Color(0xFFC8B4FF), Color(0xFFF2AEDD), Color(0xFFAEC8FF)]
            : const [Color(0xFF0A0818), Color(0xFF1D1633)],
        stops: light ? const [0.0, 0.5, 1.0] : const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final hsl = HSLColor.fromColor(base);
    final blurSigma = size.shortestSide * 0.22;

    for (final b in _blobs) {
      final color = HSLColor.fromAHSL(
        1,
        (hsl.hue + b.hueShift) % 360,
        (hsl.saturation + (light ? 0.55 : 0.45)).clamp(0.45, 1.0),
        (hsl.lightness + (light ? 0.12 : 0.02))
            .clamp(light ? 0.62 : 0.34, light ? 0.84 : 0.58),
      ).toColor();

      final paint = Paint()
        ..color = color.withOpacity(light ? 0.70 : 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      canvas.drawCircle(
        Offset(b.x * size.width, b.y * size.height),
        b.radiusFactor * size.shortestSide,
        paint,
      );
    }

    // A subtle vignette so the glass edges pop.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(light ? 0.14 : 0.42),
        ],
        stops: const [0.5, 1.0],
        radius: 0.95,
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.light != light;
}

/// Rotating rainbow-ish conic sheen used sparingly as a specular highlight.
class GlassSpecular extends StatelessWidget {
  const GlassSpecular({
    super.key,
    this.radius = 0,
    this.borderRadius,
    this.opacity = 0.18,
  });

  final double radius;
  final BorderRadius? borderRadius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: br,
        child: CustomPaint(
          painter: _SpecularPainter(opacity: opacity),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SpecularPainter extends CustomPainter {
  _SpecularPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 4,
        endAngle: math.pi * 1.75,
        transform: const GradientRotation(math.pi / 6),
        colors: [
          Colors.white.withOpacity(opacity),
          Colors.transparent,
          Colors.white.withOpacity(opacity * 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpecularPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
