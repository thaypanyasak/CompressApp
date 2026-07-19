import 'package:flutter/material.dart';
import '../compress_service.dart';

class SizeVisualizer extends StatelessWidget {
  final String label;
  final int bytes;
  final int maxBytes;
  final List<Color> progressColors;

  const SizeVisualizer({
    super.key,
    required this.label,
    required this.bytes,
    required this.maxBytes,
    required this.progressColors,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = maxBytes > 0 ? (bytes / maxBytes).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(
              CompressService.formatBytes(bytes),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: progressColors),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: progressColors.first.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
