import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../compress_service.dart';
import '../widgets/glowing_container.dart';
import '../widgets/glow_picker_area.dart';
import '../widgets/size_visualizer.dart';
import '../widgets/video_preview.dart';
import '../utils/media_utility.dart';

class VideoCompressScreen extends StatefulWidget {
  const VideoCompressScreen({super.key});

  @override
  State<VideoCompressScreen> createState() => _VideoCompressScreenState();
}

class _CompressResult {
  final File original;
  final File compressed;
  _CompressResult({required this.original, required this.compressed});
}

class _VideoCompressScreenState extends State<VideoCompressScreen> {
  List<File> _selectedVideos = [];
  List<_CompressResult> _results = [];
  VideoQuality _videoQuality = VideoQuality.MediumQuality;

  bool _isPickingFile = false;
  bool _isCompressing = false;
  bool _isCopyingToSandbox = false;

  int _currentIndex = 0;
  double _currentFileProgress = 0.0;
  double _copyProgress = 0.0;
  int _videoTimeTakenMs = 0;

  Future<void> _pickVideos() async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        allowCompression: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
        setState(() {
          _selectedVideos = files;
          _results = [];
          _currentFileProgress = 0.0;
          _videoTimeTakenMs = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเปิดไฟล์วิดีโอได้: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _compressAll() async {
    if (_selectedVideos.isEmpty) return;

    setState(() {
      _isCompressing = true;
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

      // iOS: copy to sandbox
      File workFile = srcFile;
      if (Platform.isIOS) {
        setState(() {
          _isCopyingToSandbox = true;
          _copyProgress = 0.0;
        });
        try {
          workFile = await CompressService.ensureLocalVideoPath(
            srcFile.path,
            onProgress: (p) => setState(() => _copyProgress = p),
          );
        } catch (e) {
          if (!mounted) break;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เตรียมไฟล์ iOS ล้มเหลว: $e'), backgroundColor: Colors.redAccent),
          );
          continue;
        } finally {
          if (mounted) setState(() => _isCopyingToSandbox = false);
        }
      }

      // Listen progress
      final sub = CompressService.videoProgressStream.listen((p) {
        if (mounted) setState(() => _currentFileProgress = p);
      });

      try {
        final compressed = await CompressService.compressVideo(
          sourcePath: workFile.path,
          quality: _videoQuality,
        );

        sub.cancel();

        if (compressed != null && mounted) {
          setState(() {
            _results.add(_CompressResult(original: srcFile, compressed: compressed));
          });
        }
      } catch (e) {
        sub.cancel();
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
        _videoTimeTakenMs = stopwatch.elapsedMilliseconds;
      });
    }
  }

  Future<void> _cancelCompression() async {
    await CompressService.cancelVideoCompression();
  }

  void _reset() {
    setState(() {
      _selectedVideos = [];
      _results = [];
      _currentFileProgress = 0.0;
      _videoTimeTakenMs = 0;
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
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
          const Text('• ', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return GlowingContainer(
      gradientColors: const [Color(0xFF130E26), Color(0xFF15102A)],
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF00E5FF), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'หลักการบีบอัดวิดีโอออฟไลน์คืออะไร?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00E5FF)),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text(
              '1. แอปพลิเคชันบีบอัดแบบออฟไลน์ 100% บนโทรศัพท์มือถือของคุณ',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              '2. ใช้ตัวเข้ารหัสฮาร์ดแวร์ H.264/H.265 ปรับบิตเรตให้เหมาะสม:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletPoint('ลดขนาดไฟล์ลงได้ถึง 70% - 90%'),
                  _buildBulletPoint('คงความคมชัดของภาพไว้ได้เกือบ 99%'),
                  _buildBulletPoint('รองรับการบีบอัดหลายไฟล์พร้อมกัน'),
                ],
              ),
            ),
          ],
        ),
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
            const LinearProgressIndicator(color: Color(0xFFD500F9), backgroundColor: Colors.white10, minHeight: 6),
            const SizedBox(height: 24),
            const Text('กำลังโหลดไฟล์วิดีโอ...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('ไฟล์ขนาดใหญ่อาจใช้เวลาสักครู่', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ─── PHASE: File List (before compress) ──────────────────────────────────
  Widget _buildFileListState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File list card
        GlowingContainer(
          gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          shadowColor: const Color(0xFF8E2DE2),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.video_collection_outlined, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'วิดีโอที่เลือก (${_selectedVideos.length} ไฟล์)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                    // Add more
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E5FF)),
                      tooltip: 'เพิ่มวิดีโอ',
                      onPressed: _pickVideos,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white60),
                      tooltip: 'เริ่มใหม่',
                      onPressed: _reset,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(_selectedVideos.length, (i) {
                  final f = _selectedVideos[i];
                  final name = f.path.split(Platform.pathSeparator).last;
                  final size = f.lengthSync();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E2DE2).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(CompressService.formatBytes(size), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
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

        // Settings
        GlowingContainer(
          gradientColors: const [Color(0xFFD500F9), Color(0xFF8E2DE2)],
          shadowColor: const Color(0xFFD500F9),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.purpleAccent, size: 20),
                    SizedBox(width: 8),
                    Text('ตัวเลือกการบีบอัดวิดีโอ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('คุณภาพวิดีโอปลายทาง:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('ต่ำ (ไฟล์เล็กสุด)'),
                        selected: _videoQuality == VideoQuality.LowQuality,
                        onSelected: (s) { if (s) setState(() => _videoQuality = VideoQuality.LowQuality); },
                        backgroundColor: Colors.white10,
                        selectedColor: const Color(0xFFD500F9).withOpacity(0.2),
                        labelStyle: TextStyle(color: _videoQuality == VideoQuality.LowQuality ? Colors.purpleAccent : Colors.white60, fontSize: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('กลาง (แนะนำ)'),
                        selected: _videoQuality == VideoQuality.MediumQuality,
                        onSelected: (s) { if (s) setState(() => _videoQuality = VideoQuality.MediumQuality); },
                        backgroundColor: Colors.white10,
                        selectedColor: const Color(0xFFD500F9).withOpacity(0.2),
                        labelStyle: TextStyle(color: _videoQuality == VideoQuality.MediumQuality ? Colors.purpleAccent : Colors.white60, fontSize: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('สูง (ชัดสุด)'),
                        selected: _videoQuality == VideoQuality.HighestQuality,
                        onSelected: (s) { if (s) setState(() => _videoQuality = VideoQuality.HighestQuality); },
                        backgroundColor: Colors.white10,
                        selectedColor: const Color(0xFFD500F9).withOpacity(0.2),
                        labelStyle: TextStyle(color: _videoQuality == VideoQuality.HighestQuality ? Colors.purpleAccent : Colors.white60, fontSize: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shadowColor: const Color(0xFFD500F9).withOpacity(0.5),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFD500F9), Color(0xFF8E2DE2)], begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_settings, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _selectedVideos.length == 1 ? 'เริ่มบีบอัดวิดีโอ' : 'เริ่มบีบอัด ${_selectedVideos.length} วิดีโอ',
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
    final total = _selectedVideos.length;
    final done = _results.length;
    final overallProgress = total == 0 ? 0.0 : (done + _currentFileProgress / 100) / total;

    return Column(
      children: [
        if (_isCopyingToSandbox) ...[
          GlowingContainer(
            gradientColors: const [Color(0xFF00E5FF), Color(0xFF8E2DE2)],
            shadowColor: const Color(0xFF00E5FF),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('กำลังเตรียมไฟล์วิดีโอ iOS...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white))),
                      Text('${(_copyProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: _copyProgress, color: const Color(0xFF00E5FF), backgroundColor: Colors.white10, minHeight: 8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        GlowingContainer(
          gradientColors: const [Color(0xFF00E5FF), Color(0xFFD500F9)],
          shadowColor: const Color(0xFF00E5FF),
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
                        const Text('กำลังบีบอัดวิดีโอ...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          'ไฟล์ที่ ${_currentIndex + 1} / $total',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '${_currentFileProgress.toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.cyanAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Current file progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _currentFileProgress / 100,
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
                      Text('ภาพรวม: ${done}/${total} ไฟล์', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                const SizedBox(height: 16),
                const Text(
                  'การทำงานออฟไลน์ใช้ประสิทธิภาพสูงสุดของโทรศัพท์\nโปรดอย่าปิดแอปพลิเคชัน',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _cancelCompression,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('ยกเลิกการบีบอัด'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final totalOriginalSize = _results.fold<int>(0, (s, r) => s + r.original.lengthSync());
    final totalCompressedSize = _results.fold<int>(0, (s, r) => s + r.compressed.lengthSync());
    final reduction = CompressService.getReductionPercentage(totalOriginalSize, totalCompressedSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary
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
                        Text('บีบอัดสำเร็จแล้ว!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
                _buildStatRow('จำนวนไฟล์:', '${_results.length} วิดีโอ'),
                const SizedBox(height: 8),
                _buildStatRow('เวลาที่ใช้:', '${(_videoTimeTakenMs / 1000).toStringAsFixed(1)} วินาที'),
                const SizedBox(height: 8),
                _buildStatRow('ขนาดรวมก่อน:', CompressService.formatBytes(totalOriginalSize)),
                const SizedBox(height: 8),
                _buildStatRow('ขนาดรวมหลัง:', CompressService.formatBytes(totalCompressedSize), highlight: true),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                SizeVisualizer(
                  label: 'ขนาดก่อนบีบอัด',
                  bytes: totalOriginalSize,
                  maxBytes: totalOriginalSize,
                  progressColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                ),
                const SizedBox(height: 16),
                SizeVisualizer(
                  label: 'ขนาดหลังบีบอัด',
                  bytes: totalCompressedSize,
                  maxBytes: totalOriginalSize,
                  progressColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Per-file results
        ..._results.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final origSize = r.original.lengthSync();
          final compSize = r.compressed.lengthSync();
          final red = CompressService.getReductionPercentage(origSize, compSize);
          final name = r.original.path.split(Platform.pathSeparator).last;

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
                        Expanded(child: _buildStatRow('หลังนัน:', CompressService.formatBytes(compSize), highlight: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    VideoPreviewWidget(file: r.compressed, title: ''),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => MediaUtility.saveToGallery(context, r.compressed, isVideo: true),
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
                            onPressed: () => MediaUtility.shareFile(r.compressed, 'compressed_${i + 1}.mp4'),
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
          child: const Text('บีบอัดวิดีโออื่น', style: TextStyle(color: Colors.cyanAccent)),
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
          else if (_selectedVideos.isEmpty && _results.isEmpty)
            ...[
              GlowPickerArea(
                title: 'เลือกวิดีโอเพื่อบีบอัด',
                subtitle: 'รองรับหลายไฟล์พร้อมกัน — แตะเพื่อเลือก',
                icon: Icons.video_call_rounded,
                onTap: _pickVideos,
                gradientColors: const [Color(0xFF8E2DE2), Color(0xFFD500F9)],
              ),
              const SizedBox(height: 24),
              _buildInfoCard(),
            ]
          else if (_isCompressing)
            _buildCompressingState()
          else if (_results.isNotEmpty)
            _buildResultsState()
          else if (_selectedVideos.isNotEmpty)
            _buildFileListState(),
        ],
      ),
    );
  }
}
