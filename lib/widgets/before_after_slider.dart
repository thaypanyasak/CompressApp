import 'dart:io';
import 'package:flutter/material.dart';

class BeforeAfterSlider extends StatefulWidget {
  final File beforeImage;
  final File afterImage;
  final double? height;
  final double aspectRatio;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
    this.height,
    this.aspectRatio = 1.0,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _sliderValue = 0.5; // 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final actualHeight = widget.height ?? (width / widget.aspectRatio).clamp(320.0, 680.0);
        final dividerX = width * _sliderValue;

        return Container(
          height: actualHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _sliderValue = (details.localPosition.dx / width).clamp(0.0, 1.0);
                });
              },
              child: Stack(
                children: [
                  // Layer 1: Full After (Enhanced) Image (Fixed, No Zooming)
                  Positioned.fill(
                    child: Image.file(
                      widget.afterImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Layer 2: Clipped Before (Original) Image (Fixed, No Zooming)
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _SplitClipper(dividerX),
                      child: Image.file(
                        widget.beforeImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Layer 3: Divider Line
                  Positioned(
                    left: dividerX - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: Colors.white,
                    ),
                  ),
                  // Layer 4: Drag Handle Icon
                  Positioned(
                    left: dividerX - 20,
                    top: actualHeight / 2 - 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD500F9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  // Layer 5: Badges
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ต้นฉบับ (Before)',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD500F9).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'คมชัดขึ้น (After)',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SplitClipper extends CustomClipper<Rect> {
  final double clipWidth;

  _SplitClipper(this.clipWidth);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, clipWidth, size.height);
  }

  @override
  bool shouldReclip(_SplitClipper oldClipper) {
    return oldClipper.clipWidth != clipWidth;
  }
}
