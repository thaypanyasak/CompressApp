import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
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

class _VideoCompressScreenState extends State<VideoCompressScreen> {
  File? _originalVideo;
  File? _compressedVideo;
  VideoQuality _videoQuality = VideoQuality.medium;
  double _videoProgress = 0.0;
  bool _isVideoCompressing = false;
  bool _isPickingFile = false;
  bool _isCopyingToSandbox = false; // iOS: copying file to app sandbox
  int _videoTimeTakenMs = 0;

  Future<void> _pickVideo() async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        // Get file size in background to avoid blocking UI
        final file = File(path);
        setState(() {
          _originalVideo = file;
          _compressedVideo = null;
          _videoProgress = 0.0;
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

  Future<void> _compressVideo() async {
    if (_originalVideo == null) return;

    // iOS: copy file to app sandbox first to prevent PHAsset URL revocation
    if (Platform.isIOS) {
      setState(() => _isCopyingToSandbox = true);
      try {
        final localFile = await CompressService.ensureLocalVideoPath(_originalVideo!.path);
        setState(() {
          _originalVideo = localFile;
          _isCopyingToSandbox = false;
        });
      } catch (e) {
        setState(() => _isCopyingToSandbox = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเตรียมไฟล์วิดีโอบน iOS ได้: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() {
      _isVideoCompressing = true;
      _videoProgress = 0.0;
    });

    final stopwatch = Stopwatch()..start();

    // Listen to video compression progress
    final subscription = CompressService.videoProgressStream.listen((progress) {
      setState(() {
        _videoProgress = progress;
      });
    });

    try {
      final compressed = await CompressService.compressVideo(
        sourcePath: _originalVideo!.path,
        quality: _videoQuality,
      );

      stopwatch.stop();
      subscription.cancel();

      if (compressed != null) {
        setState(() {
          _compressedVideo = compressed;
          _videoTimeTakenMs = stopwatch.elapsedMilliseconds;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยกเลิกการบีบอัดวิดีโอแล้ว'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      subscription.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบีบอัดวิดีโอ: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isVideoCompressing = false;
      });
    }
  }

  Future<void> _cancelVideoCompression() async {
    await CompressService.cancelVideoCompression();
  }

  void _resetVideo() {
    setState(() {
      _originalVideo = null;
      _compressedVideo = null;
      _videoProgress = 0.0;
      _videoTimeTakenMs = 0;
    });
  }

  Widget _buildStatRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: highlight ? Colors.cyanAccent : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCompressionExplanationCard() {
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
                Text(
                  'หลักการบีบอัดวิดีโอออฟไลน์คืออะไร?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00E5FF)),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text(
              '1. แอปพลิเคชันบีบอัดแบบออฟไลน์ 100% บนโทรศัพท์มือถือของคุณ มั่นใจได้ในความปลอดภัยและความเป็นส่วนตัวอย่างสมบูรณ์',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              '2. วิดีโอที่ถ่ายจากกล้องมือถือมักจะมีบิตเรต (bitrate) ที่สูงมาก โดยการใช้ตัวเข้ารหัสฮาร์ดแวร์ (H.264/H.265) ที่มีอยู่ในเครื่องเพื่อปรับบิตเรตให้เหมาะสมอย่างชาญฉลาด:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletPoint('ลดขนาดไฟล์ลงได้ถึง 70% - 90% อย่างมีประสิทธิภาพ'),
                  _buildBulletPoint('คงความคมชัดของภาพไว้ได้เกือบ 99% (มองด้วยตาเปล่าไม่เห็นความต่าง)'),
                  _buildBulletPoint('ประมวลผลได้รวดเร็วเนื่องจากการเร่งความเร็วด้วยฮาร์ดแวร์ของอุปกรณ์'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final originalSize = _originalVideo?.lengthSync() ?? 0;
    final compressedSize = _compressedVideo?.lengthSync() ?? 0;
    final reduction = CompressService.getReductionPercentage(originalSize, compressedSize);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isPickingFile) ...[
            GlowingContainer(
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ไฟล์วิดีโอขนาดใหญ่อาจใช้เวลาสักครู่\nโปรดรอสักครู่',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_isCopyingToSandbox) ...[
            GlowingContainer(
              gradientColors: const [Color(0xFF00E5FF), Color(0xFF8E2DE2)],
              shadowColor: const Color(0xFF00E5FF),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                child: Column(
                  children: [
                    const LinearProgressIndicator(
                      color: Color(0xFF00E5FF),
                      backgroundColor: Colors.white10,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'กำลังเตรียมไฟล์วิดีโอสำหรับ iOS...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'กำลังคัดลอกไฟล์ไปยังพื้นที่แอปเพื่อเริ่มประมวลผลได้อย่างมีเสถียรภาพ\nไฟล์ขนาดใหญ่อาจใช้เวลาสักระยะหนึ่ง...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_originalVideo == null) ...[
            GlowPickerArea(
              title: 'เลือกวิดีโอเพื่อบีบอัด',
              subtitle: 'รองรับไฟล์วิดีโอทุกขนาด (รวมถึงไฟล์ขนาดใหญ่)',
              icon: Icons.video_call_rounded,
              onTap: _pickVideo,
              gradientColors: const [Color(0xFF8E2DE2), Color(0xFFD500F9)],
            ),
            const SizedBox(height: 24),
            _buildCompressionExplanationCard(),
          ] else if (_compressedVideo == null && !_isVideoCompressing) ...[
            // Video Workspace (Before Compressing)
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
                        const Expanded(
                          child: Text(
                            'รายละเอียดไฟล์วิดีโอ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white60),
                          onPressed: _resetVideo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow('ชื่อไฟล์:', _originalVideo!.path.split(Platform.pathSeparator).last),
                    const SizedBox(height: 8),
                    _buildStatRow('ขนาดไฟล์เดิม:', CompressService.formatBytes(originalSize)),
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 14),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'iOS อาจแสดงขนาดไฟล์ที่ต่างจากต้นฉบับเนื่องจากการ Transcode HEVC→H.264 โดยอัตโนมัติ',
                                style: TextStyle(color: Colors.amber, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Video Settings
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
                        Text(
                          'ตัวเลือกการบีบอัดวิดีโอ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
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
                            selected: _videoQuality == VideoQuality.low,
                            onSelected: (selected) {
                              if (selected) setState(() => _videoQuality = VideoQuality.low);
                            },
                            backgroundColor: Colors.white10,
                            selectedColor: const Color(0xFFD500F9).withOpacity(0.2),
                            labelStyle: TextStyle(color: _videoQuality == VideoQuality.low ? Colors.purpleAccent : Colors.white60, fontSize: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('กลาง (แนะนำ)'),
                            selected: _videoQuality == VideoQuality.medium,
                            onSelected: (selected) {
                              if (selected) setState(() => _videoQuality = VideoQuality.medium);
                            },
                            backgroundColor: Colors.white10,
                            selectedColor: const Color(0xFFD500F9).withOpacity(0.2),
                            labelStyle: TextStyle(color: _videoQuality == VideoQuality.medium ? Colors.purpleAccent : Colors.white60, fontSize: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('สูง (ชัดสุด)'),
                            selected: _videoQuality == VideoQuality.high,
                            onSelected: (selected) {
                              if (selected) setState(() => _videoQuality = VideoQuality.high);
                            },
                            backgroundColor: Colors.white10,
                            selectedColor: const Color(0xFFD500F9).withOpacity(0.2),
                            labelStyle: TextStyle(color: _videoQuality == VideoQuality.high ? Colors.purpleAccent : Colors.white60, fontSize: 11),
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
              onPressed: _compressVideo,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_settings, color: Colors.white),
                      SizedBox(width: 8),
                      Text('เริ่มบีบอัดวิดีโอ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_isVideoCompressing) ...[
            // Progress Card
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
                        const Text(
                          'กำลังบีบอัดวิดีโอ...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        Text(
                          '${_videoProgress.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _videoProgress / 100,
                        color: const Color(0xFF00E5FF),
                        backgroundColor: Colors.white10,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'การทำงานออฟไลน์ใช้ประสิทธิภาพสูงสุดของโทรศัพท์\nโปรดอย่าปิดแอปพลิเคชัน',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _cancelVideoCompression,
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
          ] else ...[
            // Results view
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                Text(
                                  'บีบอัดสำเร็จแล้ว!',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'ลดลง ${reduction.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Color(0xFF080614),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildStatRow('เวลาที่ใช้บีบอัด:', '${(_videoTimeTakenMs / 1000).toStringAsFixed(1)} วินาที'),
                        const SizedBox(height: 10),
                        _buildStatRow('ความละเอียดวิดีโอ:', 'คงอัตราส่วนภาพที่เหมาะสมที่สุด'),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 16),
                        SizeVisualizer(
                          label: 'ขนาดก่อนบีบอัด',
                          bytes: originalSize,
                          maxBytes: originalSize,
                          progressColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                        ),
                        const SizedBox(height: 16),
                        SizeVisualizer(
                          label: 'ขนาดหลังบีบอัด',
                          bytes: compressedSize,
                          maxBytes: originalSize,
                          progressColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                VideoPreviewWidget(
                  file: _compressedVideo!,
                  title: 'ตัวอย่างวิดีโอหลังการบีบอัด:',
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () => MediaUtility.openFile(_compressedVideo!),
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('เล่นวิดีโอ'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => MediaUtility.saveToGallery(context, _compressedVideo!, isVideo: true),
                        icon: const Icon(Icons.save_alt_rounded),
                        label: const Text('บันทึกในคลังภาพ'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFF00E5FF).withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => MediaUtility.shareFile(_compressedVideo!, 'compressed_video.mp4'),
                        icon: const Icon(Icons.share),
                        label: const Text('แชร์ไฟล์'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF8E2DE2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFF8E2DE2).withOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _resetVideo,
                  child: const Text('บีบอัดวิดีโออื่น', style: TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
