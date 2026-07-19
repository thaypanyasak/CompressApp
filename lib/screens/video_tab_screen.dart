import 'package:flutter/material.dart';
import 'video_compress_screen.dart';
import 'video_enhance_screen.dart';

class VideoTabScreen extends StatefulWidget {
  const VideoTabScreen({super.key});

  @override
  State<VideoTabScreen> createState() => _VideoTabScreenState();
}

class _VideoTabScreenState extends State<VideoTabScreen> {
  int _activeSubTab = 0; // 0: Compress, 1: Enhance

  Widget _buildSubTabButton(int index, String label, IconData icon) {
    final isActive = _activeSubTab == index;
    final activeColor = index == 0 ? const Color(0xFF8E2DE2) : const Color(0xFFD500F9);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSubTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white38,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
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
              _buildSubTabButton(0, 'บีบอัดวิดีโอ', Icons.video_library_outlined),
              _buildSubTabButton(1, 'เพิ่มความคมชัด', Icons.auto_awesome),
            ],
          ),
        ),
        // Active Sub Tab Content
        Expanded(
          child: IndexedStack(
            index: _activeSubTab,
            children: const [
              VideoCompressScreen(),
              VideoEnhanceScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
