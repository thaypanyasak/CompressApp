import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../enhance_service.dart';
import '../compress_service.dart';
import '../widgets/glowing_container.dart';
import '../widgets/glow_picker_area.dart';
import '../widgets/before_after_slider.dart';
import '../utils/media_utility.dart';

class ImageEnhanceScreen extends StatefulWidget {
  const ImageEnhanceScreen({super.key});

  @override
  State<ImageEnhanceScreen> createState() => _ImageEnhanceScreenState();
}

class _EnhanceResult {
  final File original;
  final File enhanced;
  final String? originalResolution;
  final String? enhancedResolution;
  _EnhanceResult({required this.original, required this.enhanced, this.originalResolution, this.enhancedResolution});
}

class _ImageEnhanceScreenState extends State<ImageEnhanceScreen> {
  List<File> _selectedImages = [];
  List<_EnhanceResult> _results = [];

  double _enhanceSharpness = 2.0;
  double _enhanceUpscaleFactor = 2.0;
  bool _enableHdr = true;
  bool _enableDenoise = true;

  bool _isEnhancing = false;
  double _currentProgress = 0.0;
  int _currentIndex = 0;
  Timer? _progressTimer;
  int _enhanceTimeTakenMs = 0;

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      allowCompression: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      setState(() {
        _selectedImages = files;
        _results = [];
        _currentProgress = 0.0;
        _enhanceTimeTakenMs = 0;
      });
    }
  }

  void _startProgressSimulation() {
    _currentProgress = 0.0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_currentProgress < 80.0) {
          _currentProgress += (80.0 - _currentProgress) * 0.03 + 0.5;
        } else if (_currentProgress < 90.0) {
          _currentProgress += 0.1;
        }
        _currentProgress = _currentProgress.clamp(0.0, 90.0);
      });
    });
  }

  void _finishProgress() {
    _progressTimer?.cancel();
    if (mounted) setState(() => _currentProgress = 100.0);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _enhanceAll() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isEnhancing = true;
      _results = [];
      _currentIndex = 0;
      _currentProgress = 0.0;
    });

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < _selectedImages.length; i++) {
      if (!mounted) break;
      final srcFile = _selectedImages[i];

      setState(() {
        _currentIndex = i;
        _currentProgress = 0.0;
      });

      _startProgressSimulation();

      // Read original resolution
      String? originalRes;
      try {
        final bytes = await srcFile.readAsBytes();
        final imgObj = img.decodeImage(bytes);
        if (imgObj != null) originalRes = '${imgObj.width} x ${imgObj.height}';
      } catch (_) {}

      try {
        final tempDir = await getTemporaryDirectory();
        final outputPath = '${tempDir.path}${Platform.pathSeparator}enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final params = ImageEnhanceParams(
          sourcePath: srcFile.path,
          outputPath: outputPath,
          upscaleFactor: _enhanceUpscaleFactor,
          sharpnessLevel: _enhanceSharpness,
          enableHdr: _enableHdr,
          enableDenoise: _enableDenoise,
        );

        final result = await compute(enhanceImageWork, params);

        _finishProgress();
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          final enhancedRes = '${result.enhancedWidth} x ${result.enhancedHeight}';
          setState(() => _results.add(_EnhanceResult(
            original: srcFile,
            enhanced: File(result.path),
            originalResolution: originalRes,
            enhancedResolution: enhancedRes,
          )));
        }
      } catch (e) {
        _finishProgress();
        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไฟล์ ${srcFile.path.split(Platform.pathSeparator).last}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    stopwatch.stop();
    if (mounted) {
      setState(() {
        _isEnhancing = false;
        _enhanceTimeTakenMs = stopwatch.elapsedMilliseconds;
      });
    }
  }

  void _reset() {
    _progressTimer?.cancel();
    setState(() {
      _selectedImages = [];
      _results = [];
      _currentProgress = 0.0;
      _enhanceTimeTakenMs = 0;
    });
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  String _getSharpnessLabel(double val) {
    if (val == 1.0) return 'บางเบา (Mild)';
    if (val == 2.0) return 'มาตรฐาน (Normal)';
    if (val == 3.0) return 'ชัดเจน (Strong)';
    return 'สูงสุด (Ultra 4K)';
  }

  Widget _buildStatRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: highlight ? Colors.cyanAccent : Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildUpscalePill(double factor, String label) {
    final isSelected = _enhanceUpscaleFactor == factor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _enhanceUpscaleFactor = factor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD500F9).withOpacity(0.15) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFD500F9) : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  // ─── PHASE: Empty picker ─────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return GlowPickerArea(
      title: 'เลือกรูปภาพเพื่อเพิ่มความคมชัด',
      subtitle: 'รองรับหลายภาพพร้อมกัน — JPG, PNG ประมวลผลออฟไลน์ 100%',
      icon: Icons.auto_awesome_motion_rounded,
      onTap: _pickImages,
      gradientColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
    );
  }

  // ─── PHASE: File List (before enhance) ───────────────────────────────────
  Widget _buildFileListState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image list card
        GlowingContainer(
          gradientColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
          shadowColor: const Color(0xFF00E5FF),
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_size_select_actual_outlined, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'รูปภาพที่เลือก (${_selectedImages.length} ภาพ)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E5FF)),
                      tooltip: 'เพิ่มรูปภาพ',
                      onPressed: _pickImages,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white60),
                      onPressed: _reset,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_selectedImages.length, (i) {
                    final name = _selectedImages[i].path.split(Platform.pathSeparator).last;
                    return Chip(
                      avatar: const Icon(Icons.image, size: 16, color: Color(0xFF00E5FF)),
                      label: Text(
                        name.length > 18 ? '${name.substring(0, 15)}...' : name,
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                      onDeleted: () => _removeImage(i),
                      backgroundColor: Colors.white.withOpacity(0.07),
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Settings card
        GlowingContainer(
          gradientColors: const [Color(0xFFD500F9), Color(0xFF8E2DE2)],
          shadowColor: const Color(0xFFD500F9),
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.purpleAccent, size: 20),
                    SizedBox(width: 8),
                    Text('ตั้งค่าการเพิ่มความละเอียดระดับ 4K', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('ระดับการขยายความละเอียด (Upscale)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildUpscalePill(1.0, '1x (เท่าเดิม)'),
                    const SizedBox(width: 8),
                    _buildUpscalePill(2.0, '2x (ชัด 2 เท่า)'),
                    const SizedBox(width: 8),
                    _buildUpscalePill(4.0, '4x (ระดับ 4K)'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Text('ระดับความคมชัด (Sharpness)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFD500F9).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(_getSharpnessLabel(_enhanceSharpness), style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Slider(
                  value: _enhanceSharpness,
                  min: 1.0, max: 4.0, divisions: 3,
                  activeColor: const Color(0xFFD500F9),
                  inactiveColor: Colors.white10,
                  onChanged: (val) => setState(() => _enhanceSharpness = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('HDR Color Boost'),
                        selected: _enableHdr,
                        labelStyle: TextStyle(color: _enableHdr ? Colors.cyanAccent : Colors.white60, fontSize: 11, fontWeight: _enableHdr ? FontWeight.bold : FontWeight.normal),
                        onSelected: (val) => setState(() => _enableHdr = val),
                        selectedColor: const Color(0xFFD500F9).withOpacity(0.25),
                        checkmarkColor: Colors.cyanAccent,
                        backgroundColor: Colors.white.withOpacity(0.04),
                        side: BorderSide(color: _enableHdr ? const Color(0xFFD500F9) : Colors.white12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterChip(
                        label: const Text('Denoise & Smooth'),
                        selected: _enableDenoise,
                        labelStyle: TextStyle(color: _enableDenoise ? Colors.cyanAccent : Colors.white60, fontSize: 11, fontWeight: _enableDenoise ? FontWeight.bold : FontWeight.normal),
                        onSelected: (val) => setState(() => _enableDenoise = val),
                        selectedColor: const Color(0xFFD500F9).withOpacity(0.25),
                        checkmarkColor: Colors.cyanAccent,
                        backgroundColor: Colors.white.withOpacity(0.04),
                        side: BorderSide(color: _enableDenoise ? const Color(0xFFD500F9) : Colors.white12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _enhanceAll,
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: Text(
                    _selectedImages.length == 1 ? 'เริ่มประมวลผลเพิ่มความคมชัด' : 'เพิ่มความคมชัด ${_selectedImages.length} ภาพ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFFD500F9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: const Color(0xFFD500F9).withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── PHASE: Enhancing ────────────────────────────────────────────────────
  Widget _buildEnhancingState() {
    final total = _selectedImages.length;
    final done = _results.length;
    final overallProgress = total == 0 ? 0.0 : (done + _currentProgress / 100) / total;

    return GlowingContainer(
      gradientColors: const [Color(0xFF00E5FF), Color(0xFFD500F9)],
      shadowColor: const Color(0xFF00E5FF),
      borderRadius: 24,
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
                    const Text('กำลังเพิ่มความคมชัด 4K...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('ภาพที่ ${_currentIndex + 1} / $total', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                Text('${_currentProgress.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.cyanAccent)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _currentProgress / 100,
                color: const Color(0xFF00E5FF),
                backgroundColor: Colors.white10,
                minHeight: 8,
              ),
            ),
            if (total > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ภาพรวม: ${done}/${total} ภาพ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('${(overallProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: overallProgress,
                  color: const Color(0xFFD500F9),
                  backgroundColor: Colors.white10,
                  minHeight: 5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'ประมวลผลบนเครื่องแบบ Offline 100%\nโปรดอย่าปิดแอปพลิเคชัน',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
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
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
                    SizedBox(width: 8),
                    Text('เพิ่มความคมชัดเรียบร้อยแล้ว!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStatRow('จำนวน:', '${_results.length} ภาพ'),
                const SizedBox(height: 4),
                _buildStatRow('เวลาที่ใช้:', '${(_enhanceTimeTakenMs / 1000).toStringAsFixed(2)} วินาที'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        ..._results.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final name = r.original.path.split(Platform.pathSeparator).last;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: GlowingContainer(
              gradientColors: const [Color(0xFF130E26), Color(0xFF1A1435)],
              shadowColor: Colors.transparent,
              borderRadius: 20,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: const Color(0xFFD500F9).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: const TextStyle(color: Color(0xFFD500F9), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFD500F9).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Text('✓ เสร็จ', style: TextStyle(color: Color(0xFFD500F9), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (r.originalResolution != null) _buildStatRow('ความละเอียดต้นฉบับ:', r.originalResolution!),
                    if (r.enhancedResolution != null) ...[
                      const SizedBox(height: 4),
                      _buildStatRow('ความละเอียดใหม่:', r.enhancedResolution!, highlight: true),
                    ],
                    const SizedBox(height: 4),
                    _buildStatRow('ขนาดไฟล์ใหม่:', CompressService.formatBytes(r.enhanced.lengthSync())),
                    // Before/After only for single image
                    if (_results.length == 1) ...[
                      const SizedBox(height: 12),
                      const Text('เปรียบเทียบรูปภาพ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      BeforeAfterSlider(beforeImage: r.original, afterImage: r.enhanced, height: 400),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => MediaUtility.saveToGallery(context, r.enhanced, isVideo: false),
                            icon: const Icon(Icons.save_alt_rounded, size: 16),
                            label: const Text('บันทึก', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00E5FF),
                              side: const BorderSide(color: Color(0xFF00E5FF)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => MediaUtility.shareFile(r.enhanced, 'enhanced_${i + 1}.jpg'),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('แชร์', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purpleAccent,
                              side: const BorderSide(color: Colors.purpleAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          child: const Text('เพิ่มความคมชัดรูปภาพอื่น', style: TextStyle(color: Colors.cyanAccent)),
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
          if (_selectedImages.isEmpty && _results.isEmpty)
            _buildEmptyState()
          else if (_isEnhancing)
            _buildEnhancingState()
          else if (_results.isNotEmpty)
            _buildResultsState()
          else if (_selectedImages.isNotEmpty)
            _buildFileListState(),
        ],
      ),
    );
  }
}
