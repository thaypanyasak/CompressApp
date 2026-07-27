import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../compress_service.dart';
import '../widgets/glowing_container.dart';
import '../widgets/glow_picker_area.dart';
import '../widgets/size_visualizer.dart';
import '../widgets/before_after_slider.dart';
import '../utils/media_utility.dart';

class ImageCompressScreen extends StatefulWidget {
  const ImageCompressScreen({super.key});

  @override
  State<ImageCompressScreen> createState() => _ImageCompressScreenState();
}

class _CompressResult {
  final File original;
  final File compressed;
  _CompressResult({required this.original, required this.compressed});
}

class _ImageCompressScreenState extends State<ImageCompressScreen> {
  List<File> _selectedImages = [];
  List<_CompressResult> _results = [];
  double _imageQuality = 80.0;
  CompressFormat _imageFormat = CompressFormat.jpeg;
  String _imageResolutionLimit = 'Original';

  bool _isCompressing = false;
  double _currentProgress = 0.0;
  int _currentIndex = 0;
  Timer? _progressTimer;
  int _imageTimeTakenMs = 0;

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
        _imageTimeTakenMs = 0;
      });
    }
  }

  void _startProgressSimulation() {
    _currentProgress = 0.0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_currentProgress < 85.0) {
          _currentProgress += (85.0 - _currentProgress) * 0.04 + 0.3;
        } else if (_currentProgress < 92.0) {
          _currentProgress += 0.08;
        }
        _currentProgress = _currentProgress.clamp(0.0, 92.0);
      });
    });
  }

  void _finishProgress() {
    _progressTimer?.cancel();
    if (mounted) setState(() => _currentProgress = 100.0);
  }

  Future<void> _compressAll() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isCompressing = true;
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

      try {
        int? minWidth;
        int? minHeight;
        if (_imageResolutionLimit == '1080p') {
          minWidth = 1920; minHeight = 1080;
        } else if (_imageResolutionLimit == '720p') {
          minWidth = 1280; minHeight = 720;
        }

        final compressed = await CompressService.compressImage(
          sourcePath: srcFile.path,
          quality: _imageQuality.toInt(),
          minWidth: minWidth,
          minHeight: minHeight,
          format: _imageFormat,
        );

        _finishProgress();
        await Future.delayed(const Duration(milliseconds: 200));

        if (compressed != null && mounted) {
          setState(() => _results.add(_CompressResult(original: srcFile, compressed: compressed)));
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
        _isCompressing = false;
        _imageTimeTakenMs = stopwatch.elapsedMilliseconds;
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _progressTimer?.cancel();
    setState(() {
      _selectedImages = [];
      _results = [];
      _currentProgress = 0.0;
      _imageTimeTakenMs = 0;
    });
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
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

  // ─── PHASE: Empty picker ─────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Column(
      children: [
        GlowPickerArea(
          title: 'เลือกรูปภาพเพื่อบีบอัด',
          subtitle: 'รองรับหลายภาพพร้อมกัน — แตะเพื่อเลือก',
          icon: Icons.add_photo_alternate_rounded,
          onTap: _pickImages,
          gradientColors: const [Color(0xFFE040FB), Color(0xFF00E5FF)],
        ),
      ],
    );
  }

  // ─── PHASE: File List (before compress) ──────────────────────────────────
  Widget _buildFileListState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowingContainer(
          gradientColors: const [Color(0xFFE040FB), Color(0xFF00E5FF)],
          shadowColor: const Color(0xFFE040FB),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.image_outlined, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('รูปภาพที่เลือก (${_selectedImages.length} ภาพ)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
                // Scrollable image chips
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

        // Settings
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
                    Icon(Icons.tune_rounded, color: Color(0xFF00E5FF), size: 20),
                    SizedBox(width: 8),
                    Text('ตัวเลือกการบีบอัด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('คุณภาพของรูปภาพ:', style: TextStyle(color: Colors.white70)),
                    Text('${_imageQuality.toInt()}%', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _imageQuality,
                  min: 10, max: 100, divisions: 90,
                  activeColor: const Color(0xFF00E5FF),
                  inactiveColor: Colors.white10,
                  onChanged: (val) => setState(() => _imageQuality = val),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('นามสกุลไฟล์ปลายทาง:', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF130E29).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CompressFormat>(
                          value: _imageFormat,
                          dropdownColor: const Color(0xFF1A1435),
                          borderRadius: BorderRadius.circular(16),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00E5FF)),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: CompressFormat.jpeg, child: Text('JPEG')),
                            DropdownMenuItem(value: CompressFormat.png, child: Text('PNG')),
                            DropdownMenuItem(value: CompressFormat.webp, child: Text('WEBP (แนะนำ)')),
                            DropdownMenuItem(value: CompressFormat.heic, child: Text('HEIC')),
                          ],
                          onChanged: (val) { if (val != null) setState(() => _imageFormat = val); },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('จำกัดความละเอียด:', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF130E29).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _imageResolutionLimit,
                          dropdownColor: const Color(0xFF1A1435),
                          borderRadius: BorderRadius.circular(16),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00E5FF)),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'Original', child: Text('คงขนาดเดิม')),
                            DropdownMenuItem(value: '1080p', child: Text('สูงสุด 1080p')),
                            DropdownMenuItem(value: '720p', child: Text('สูงสุด 720p')),
                          ],
                          onChanged: (val) { if (val != null) setState(() => _imageResolutionLimit = val); },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _compressAll,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 8,
            shadowColor: const Color(0xFF8E2DE2).withOpacity(0.5),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.compress, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _selectedImages.length == 1 ? 'เริ่มบีบอัดรูปภาพ' : 'เริ่มบีบอัด ${_selectedImages.length} ภาพ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── PHASE: Compressing ──────────────────────────────────────────────────
  Widget _buildCompressingState() {
    final total = _selectedImages.length;
    final done = _results.length;
    final overallProgress = total == 0 ? 0.0 : (done + _currentProgress / 100) / total;

    return GlowingContainer(
      gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      shadowColor: const Color(0xFF8E2DE2),
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
                    const Text('กำลังบีบอัดรูปภาพ...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
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
    final totalOriginalSize = _results.fold<int>(0, (s, r) => s + r.original.lengthSync());
    final totalCompressedSize = _results.fold<int>(0, (s, r) => s + r.compressed.lengthSync());
    final reduction = CompressService.getReductionPercentage(totalOriginalSize, totalCompressedSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary card
        GlowingContainer(
          gradientColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
          shadowColor: const Color(0xFF00E5FF),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
                        SizedBox(width: 8),
                        Text('ผลลัพธ์การบีบอัด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Text('ลดลง ${reduction.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Color(0xFF080614), fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildStatRow('จำนวน:', '${_results.length} ภาพ'),
                const SizedBox(height: 8),
                _buildStatRow('เวลาที่ใช้:', '${(_imageTimeTakenMs / 1000).toStringAsFixed(2)} วินาที'),
                const SizedBox(height: 8),
                _buildStatRow('ขนาดรวมก่อน:', CompressService.formatBytes(totalOriginalSize)),
                const SizedBox(height: 8),
                _buildStatRow('ขนาดรวมหลัง:', CompressService.formatBytes(totalCompressedSize), highlight: true),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                SizeVisualizer(
                  label: 'ขนาดก่อนบีบอัด', bytes: totalOriginalSize, maxBytes: totalOriginalSize,
                  progressColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                ),
                const SizedBox(height: 16),
                SizeVisualizer(
                  label: 'ขนาดหลังบีบอัด', bytes: totalCompressedSize, maxBytes: totalOriginalSize,
                  progressColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Per-file results (show before/after slider for each)
        ..._results.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final origSize = r.original.lengthSync();
          final compSize = r.compressed.lengthSync();
          final red = CompressService.getReductionPercentage(origSize, compSize);
          final name = r.original.path.split(Platform.pathSeparator).last;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: const Color(0xFF00E5FF).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('-${red.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildStatRow('เดิม:', CompressService.formatBytes(origSize))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatRow('ใหม่:', CompressService.formatBytes(compSize), highlight: true)),
                      ],
                    ),
                    // Only show before/after for single image to avoid heavy UI
                    if (_results.length == 1) ...[
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text('เปรียบเทียบรูปภาพ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                      BeforeAfterSlider(beforeImage: r.original, afterImage: r.compressed, height: 400),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => MediaUtility.saveToGallery(context, r.compressed, isVideo: false),
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
                            onPressed: () => MediaUtility.shareFile(r.compressed, 'compressed_${i + 1}.jpg'),
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
          child: const Text('บีบอัดภาพอื่น', style: TextStyle(color: Colors.cyanAccent)),
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
          else if (_isCompressing)
            _buildCompressingState()
          else if (_results.isNotEmpty)
            _buildResultsState()
          else if (_selectedImages.isNotEmpty)
            _buildFileListState(),
        ],
      ),
    );
  }
}
