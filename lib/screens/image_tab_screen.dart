import 'package:flutter/material.dart';
import 'image_compress_screen.dart';
import 'image_enhance_screen.dart';
import 'format_converter_screen.dart';

class ImageTabScreen extends StatefulWidget {
  const ImageTabScreen({super.key});

  @override
  State<ImageTabScreen> createState() => _ImageTabScreenState();
}

class _ImageTabScreenState extends State<ImageTabScreen> {
  int _activeSubTab = 0; // 0: Compress, 1: Enhance, 2: Convert

  Widget _buildSubTabButton(int index, String label, IconData icon) {
    final isActive = _activeSubTab == index;
    final activeColor = index == 0
        ? const Color(0xFF00E5FF)
        : (index == 1 ? const Color(0xFFD500F9) : const Color(0xFF8E2DE2));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSubTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? activeColor : Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white38,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Sub Tab Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF130E29).withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              _buildSubTabButton(0, 'บีบอัด', Icons.compress),
              _buildSubTabButton(1, 'เพิ่มความคมชัด', Icons.auto_awesome),
              _buildSubTabButton(2, 'แปลงไฟล์', Icons.transform_rounded),
            ],
          ),
        ),
        // Active Sub Tab Content
        Expanded(
          child: IndexedStack(
            index: _activeSubTab,
            children: const [
              ImageCompressScreen(),
              ImageEnhanceScreen(),
              FormatConverterScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
