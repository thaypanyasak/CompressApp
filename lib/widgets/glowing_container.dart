import 'package:flutter/material.dart';
import 'gradient_border_painter.dart';

class GlowingContainer extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final Color shadowColor;
  final double borderRadius;
  final double borderWidth;
  final double blurRadius;

  const GlowingContainer({
    super.key,
    required this.child,
    this.gradientColors = const [Color(0xFFE040FB), Color(0xFF00E5FF)],
    this.shadowColor = const Color(0xFFE040FB),
    this.borderRadius = 20.0,
    this.borderWidth = 1.2,
    this.blurRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.08),
            blurRadius: blurRadius,
            spreadRadius: 2,
          )
        ],
      ),
      child: CustomPaint(
        painter: GradientBorderPainter(
          gradientColors: gradientColors,
          borderRadius: borderRadius,
          borderWidth: borderWidth,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
          child: Container(
            color: const Color(0xFF130E29).withOpacity(0.65),
            child: child,
          ),
        ),
      ),
    );
  }
}
