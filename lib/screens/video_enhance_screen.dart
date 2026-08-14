import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../compress_service.dart';
import '../utils/media_utility.dart';
import '../video_enhance_service.dart';
import '../widgets/glow_picker_area.dart';
import '../widgets/glowing_container.dart';
import '../widgets/video_preview.dart';

class VideoEnhanceScreen extends StatefulWidget {
  const VideoEnhanceScreen({super.key});

  @override
  State<VideoEnhanceScreen> createState() => _VideoEnhanceScreenState();
}

class _EnhanceResult {
  final File original;
  final File enhanced;
  final VideoEnhanceResult info;
  _EnhanceResult({
    required this.original,
    required this.enhanced,
    required this.info,
  });
}

class _VideoEnhanceScreenState extends State<VideoEnhanceScreen> {
  List<File> _selectedVideos = [];
  List<_EnhanceResult> _results = [];

  bool _isPickingFile = false;
  bool _isEnhancing = false;

  int _currentIndex = 0;
  double _currentFileProgress = 0.0;
  int _timeTakenMs = 0;

  // ── Settings ────────────────────────────────────────────────────────────
  EnhanceResolution _enhanceResolution = EnhanceResolution.uhd4k;
  double _videoSharpness = 2.0; // 1..4
  bool _enableHdr = true;
  bool _enableDenoise = true;
  int _fpsTarget = 0; // 0 = giữ nguyên

  static const _fpsOptions = <int>[0, 30, 60, 120];
  static const _fpsLabels = <int, String>{
    0: 'ตามไฟล์เดิม',
    30: '30 FPS',
    60: '60 FPS',
    120: '120 FPS',
  };

  Future<void> _pickVideos() async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final files =
            result.files
                .where((f) => f.path != null)
                .map((f) => File(f.path!))
                .toList();
        setState(() {
          _selectedVideos = files;
          _results = [];
          _currentFileProgress = 0.0;
          _timeTakenMs = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _enhanceAll() async {
    if (_selectedVideos.isEmpty) return;

    setState(() {
      _isEnhancing = true;
      _results = [];
      _currentIndex = 0;
      _currentFileProgress = 0.0;
    });

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < _selectedVideos.length; i++) {
      if (!mounted) break;
      final srcFile = _selectedVideos[i];

      setState(() {
        _currentIndex = i;
        _currentFileProgress = 0.0;
      });

      // iPad/iPhone: sao chép vào sandbox trước khi xử lý
      File workFile = srcFile;
      if (Platform.isIOS) {
        try {
          workFile = await CompressService.ensureLocalVideoPath(
            srcFile.path,
            onProgress: (p) => setState(() => _currentFileProgress = p * 100),
          );
        } catch (e) {
          if (!mounted) break;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เตรียมไฟล์ iOS ล้มเหลว: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
          continue;
        }
      }

      final outputPath = await VideoEnhanceService.makeOutputPath();

      try {
        final enhanced = await VideoEnhanceService.enhanceVideo(
          VideoEnhanceParams(
            sourcePath: workFile.path,
            outputPath: outputPath,
            resolution: _enhanceResolution,
            sharpness: _videoSharpness,
            enableDenoise: _enableDenoise,
            enableHdr: _enableHdr,
            fps: _fpsTarget,
          ),
          onProgress: (p) {
            if (mounted) setState(() => _currentFileProgress = p * 100);
          },
        );

        if (!mounted) break;

        final enhancedFile = File(enhanced.path);
        setState(() {
          _currentFileProgress = 100.0;
          _results.add(
            _EnhanceResult(
              original: srcFile,
              enhanced: enhancedFile,
              info: enhanced,
            ),
          );
        });
      } catch (e) {
        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ไฟล์ ${srcFile.path.split(Platform.pathSeparator).last}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        if (Platform.isIOS) {
          await CompressService.cleanupLocalCopy(workFile, srcFile.path);
        }
      }
    }

    stopwatch.stop();
    if (mounted) {
      setState(() {
        _isEnhancing = false;
        _timeTakenMs = stopwatch.elapsedMilliseconds;
      });
    }
  }

  Future<void> _cancelEnhance() async {
    await VideoEnhanceService.cancelAll();
    if (mounted) setState(() => _isEnhancing = false);
  }

  void _reset() {
    setState(() {
      _selectedVideos = [];
      _results = [];
      _currentFileProgress = 0.0;
      _timeTakenMs = 0;
    });
  }

  void _removeVideo(int index) {
    setState(() => _selectedVideos.removeAt(index));
  }

  String _getSharpnessLabel(double val) {
    if (val == 1.0) return 'บางเบา (Mild)';
    if (val == 2.0) return 'มาตรฐาน (Normal)';
    if (val == 3.0) return 'ชัดเจน (Strong)';
    return 'สูงสุด (Ultra 4K)';
  }

  String _fpsFormat(double? fps) {
    if (fps == null || fps <= 0) return '-';
    return fps.toStringAsFixed(0);
  }

  Widget _buildStatRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: highlight ? Colors.cyanAccent : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: Color(0xFFD500F9),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PHASE: Picking ──────────────────────────────────────────────────────
  Widget _buildPickingState() {
    return GlowingContainer(
      gradientColors: const [Color(0xFF8E2DE2), Color(0xFFD500F9)],
      shadowColor: const Color(0xFF8E2DE2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            const LinearProgressIndicator(
              color: Color(0xFFD500F9),
              backgroundColor: Colors.white10,
              minHeight: 6,
            ),
            const SizedBox(height: 24),
            const Text(
              'กำลังโหลดไฟล์วิดีโอ...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Toggle chip helper ──────────────────────────────────────────────────
  Widget _buildToggleChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color color = const Color(0xFF00E5FF),
  }) {
    return Expanded(
      child: FilterChip(
        label: Text(label),
        selected: value,
        labelStyle: TextStyle(
          color: value ? color : Colors.white60,
          fontSize: 11,
          fontWeight: value ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: onChanged,
        selectedColor: color.withOpacity(0.25),
        checkmarkColor: color,
        backgroundColor: Colors.white.withOpacity(0.04),
        side: BorderSide(color: value ? color : Colors.white12),
      ),
    );
  }

  // ─── PHASE: File List (before enhance) ───────────────────────────────────
  Widget _buildFileListState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowingContainer(
          gradientColors: const [Color(0xFFD500F9), Color(0xFF8E2DE2)],
          shadowColor: const Color(0xFFD500F9),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.video_collection_outlined,
                      color: Colors.purpleAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'วิดีโอที่เลือก (${_selectedVideos.length} ไฟล์)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF00E5FF),
                      ),
                      tooltip: 'เพิ่มวิดีโอ',
                      onPressed: _pickVideos,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white60,
                      ),
                      onPressed: _reset,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(_selectedVideos.length, (i) {
                  final f = _selectedVideos[i];
                  final name = f.path.split(Platform.pathSeparator).last;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD500F9).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                CompressService.formatBytes(f.lengthSync()),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeVideo(i),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Settings ─────────────────────────────────────────────────────
        GlowingContainer(
          gradientColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
          shadowColor: const Color(0xFF00E5FF),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF00E5FF),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'การตั้งค่าการปรับความคมชัดวิดีโอ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Resolution
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ความละเอียดปลายทาง:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF130E29).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EnhanceResolution>(
                          value: _enhanceResolution,
                          dropdownColor: const Color(0xFF1A1435),
                          borderRadius: BorderRadius.circular(16),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF00E5FF),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          items:
                              EnhanceResolution.values
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.label),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _enhanceResolution = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Sharpness
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ระดับความคมชัดเฟรม (Sharpness)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getSharpnessLabel(_videoSharpness),
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _videoSharpness,
                  min: 1.0,
                  max: 4.0,
                  divisions: 3,
                  activeColor: const Color(0xFF00E5FF),
                  inactiveColor: Colors.white10,
                  onChanged: (val) => setState(() => _videoSharpness = val),
                ),
                const SizedBox(height: 12),

                // HDR + Denoise
                Row(
                  children: [
                    _buildToggleChip(
                      label: 'HDR Color Boost',
                      value: _enableHdr,
                      onChanged: (val) => setState(() => _enableHdr = val),
                    ),
                    const SizedBox(width: 8),
                    _buildToggleChip(
                      label: 'Denoise & Smooth',
                      value: _enableDenoise,
                      onChanged: (val) => setState(() => _enableDenoise = val),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── FPS Smoothing ────────────────────────────────────────
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.speed_rounded,
                      color: Color(0xFFD500F9),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'เพิ่มความเนียน FPS (Interpolation)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'ใช้เทคโนโลยี Motion Interpolation สร้างเฟรมกลาง ให้วิดีโอไหลลื่นขึ้น',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'FPS ปลายทาง:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ..._fpsOptions.map((f) {
                      final selected = _fpsTarget == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_fpsLabels[f]!),
                          selected: selected,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.white60,
                          ),
                          selectedColor: const Color(0xFFD500F9),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          side: BorderSide(
                            color:
                                selected
                                    ? const Color(0xFFD500F9)
                                    : Colors.white12,
                          ),
                          onSelected: (_) => setState(() => _fpsTarget = f),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Enhance button
        ElevatedButton(
          onPressed: _enhanceAll,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 8,
            shadowColor: const Color(0xFFD500F9).withOpacity(0.5),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD500F9), Color(0xFF8E2DE2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _selectedVideos.length == 1
                        ? 'เริ่มเพิ่มความคมชัดวิดีโอ'
                        : 'เพิ่มความคมชัด ${_selectedVideos.length} วิดีโอ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── PHASE: Enhancing ────────────────────────────────────────────────────
  Widget _buildEnhancingState() {
    final total = _selectedVideos.length;
    final done = _results.length;
    final overallProgress =
        total == 0 ? 0.0 : (done + _currentFileProgress / 100) / total;

    final tasks = <String>[];
    if (_enableDenoise) tasks.add('Khử nhiễu');
    if (_enhanceResolution.width > 0) {
      tasks.add('Nâng độ phân giải ${_enhanceResolution.label}');
    }
    if (_videoSharpness > 0) tasks.add('Tăng độ sắc nét');
    if (_enableHdr) tasks.add('HDR');
    if (_fpsTarget > 0) tasks.add('Làm mượt ${_fpsTarget}FPS');

    return Column(
      children: [
        GlowingContainer(
          gradientColors: const [Color(0xFFD500F9), Color(0xFF8E2DE2)],
          shadowColor: const Color(0xFFD500F9),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'กำลังประมวลผลวิดีโอด้วย FFmpeg...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ไฟล์ที่ ${_currentIndex + 1} / $total',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_currentFileProgress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _currentFileProgress / 100,
                    color: const Color(0xFFD500F9),
                    backgroundColor: Colors.white10,
                    minHeight: 8,
                  ),
                ),
                if (total > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ภาพรวม: ${done}/${total} ไฟล์',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(overallProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      color: const Color(0xFF00E5FF),
                      backgroundColor: Colors.white10,
                      minHeight: 5,
                    ),
                  ),
                ],
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        tasks
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD500F9,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFD500F9,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    color: Color(0xFFE040FB),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'กำลังใช้ FFmpeg ประมวลผลจริง (filter: sharp, scale, denoise, HDR, minterpolate)\nโปรดอย่าปิดแอปพลิเคชัน',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _cancelEnhance,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('ยกเลิก', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── PHASE: Results ──────────────────────────────────────────────────────
  Widget _buildResultsState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowingContainer(
          gradientColors: const [Color(0xFF00E5FF), Color(0xFFD500F9)],
          shadowColor: const Color(0xFF00E5FF),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'เพิ่มความคมชัดสำเร็จแล้ว!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildStatRow('จำนวนไฟล์:', '${_results.length} วิดีโอ'),
                const SizedBox(height: 8),
                _buildStatRow(
                  'เวลาที่ใช้:',
                  '${(_timeTakenMs / 1000).toStringAsFixed(1)} วินาที',
                ),
                const SizedBox(height: 8),
                _buildStatRow('ความละเอียดปลายทาง:', _enhanceResolution.label),
                if (_fpsTarget > 0) ...[
                  const SizedBox(height: 8),
                  _buildStatRow('FPS ปลายทาง:', '${_fpsTarget} FPS'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        ..._results.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final name = r.original.path.split(Platform.pathSeparator).last;
          final sameRes =
              r.info.originalWidth == r.info.enhancedWidth &&
              r.info.originalHeight == r.info.enhancedHeight;
          final resChanged = !sameRes && r.info.enhancedWidth > 0;
          final fpsChanged =
              r.info.enhancedFps > 0 &&
              (r.info.enhancedFps - r.info.originalFps).abs() > 0.5;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GlowingContainer(
              gradientColors: const [Color(0xFF130E26), Color(0xFF1A1435)],
              shadowColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD500F9).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Color(0xFFD500F9),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD500F9).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✓ เสร็จ',
                            style: TextStyle(
                              color: Color(0xFFD500F9),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildStatRow(
                      'ขนาดไฟล์ปลายทาง:',
                      CompressService.formatBytes(r.enhanced.lengthSync()),
                      highlight: true,
                    ),
                    const SizedBox(height: 6),
                    _buildStatRow(
                      'ความละเอียด:',
                      '${r.info.originalWidth}×${r.info.originalHeight} → ${r.info.enhancedWidth}×${r.info.enhancedHeight}',
                      highlight: resChanged,
                    ),
                    const SizedBox(height: 6),
                    _buildStatRow(
                      'FPS:',
                      '${_fpsFormat(r.info.originalFps)} → ${_fpsFormat(r.info.enhancedFps)}',
                      highlight: fpsChanged,
                    ),
                    const SizedBox(height: 10),
                    VideoPreviewWidget(file: r.enhanced, title: ''),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                () => MediaUtility.saveToGallery(
                                  context,
                                  r.enhanced,
                                  isVideo: true,
                                ),
                            icon: const Icon(Icons.save_alt_rounded, size: 16),
                            label: const Text(
                              'บันทึก',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00E5FF),
                              side: const BorderSide(color: Color(0xFF00E5FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                () => MediaUtility.shareFile(
                                  r.enhanced,
                                  'enhanced_${i + 1}.mp4',
                                ),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text(
                              'แชร์',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purpleAccent,
                              side: const BorderSide(
                                color: Colors.purpleAccent,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),
        TextButton(
          onPressed: _reset,
          child: const Text(
            'เพิ่มความคมชัดวิดีโออื่น',
            style: TextStyle(color: Colors.cyanAccent),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isPickingFile)
            _buildPickingState()
          else if (_selectedVideos.isEmpty && _results.isEmpty) ...[
            GlowPickerArea(
              title: 'เลือกวิดีโอเพื่อเพิ่มความคมชัด',
              subtitle: 'รองรับหลายไฟล์พร้อมกัน — ประมวลผลด้วย FFmpeg filter',
              icon: Icons.video_call_rounded,
              onTap: _pickVideos,
              gradientColors: const [Color(0xFFD500F9), Color(0xFF8E2DE2)],
            ),
            const SizedBox(height: 24),
            GlowingContainer(
              gradientColors: const [Color(0xFF130E26), Color(0xFF15102A)],
              shadowColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFFD500F9),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ฟังก์ชั่นเพิ่มความคมชัดวิดีโอ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFFD500F9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    const Text(
                      'ใช้เอนจิน FFmpeg ประมวลผลจริงทุกเฟรม:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint(
                            'เพิ่มความคมชัดเฟรมด้วย filter unsharp (1–4)',
                          ),
                          _buildBulletPoint(
                            'ขยายความละเอียด 720p → 4K với scale + lanczos',
                          ),
                          _buildBulletPoint(
                            'ลดสัญญาณรบกวนด้วย hqdn3d, เพิ่มสีด้วย HDR (eq)',
                          ),
                          _buildBulletPoint(
                            'สร้างเฟรมกลางให้เนียนขึ้นด้วย minterpolate (FPS)',
                          ),
                          _buildBulletPoint('ประมวลผลแบบออฟไลน์ 100%'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_isEnhancing)
            _buildEnhancingState()
          else if (_results.isNotEmpty)
            _buildResultsState()
          else if (_selectedVideos.isNotEmpty)
            _buildFileListState(),
        ],
      ),
    );
  }
}
