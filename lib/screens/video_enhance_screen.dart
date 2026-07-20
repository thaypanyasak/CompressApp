import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import '../compress_service.dart';
import '../widgets/glowing_container.dart';
import '../widgets/glow_picker_area.dart';
import '../widgets/video_preview.dart';
import '../utils/media_utility.dart';

class VideoEnhanceScreen extends StatefulWidget {
  const VideoEnhanceScreen({super.key});

  @override
  State<VideoEnhanceScreen> createState() => _VideoEnhanceScreenState();
}

class _VideoEnhanceScreenState extends State<VideoEnhanceScreen> {
  File? _originalVideo;
  File? _enhancedVideo;
  double _progress = 0.0;
  bool _isEnhancing = false;
  bool _isPickingFile = false;
  bool _isCopyingToSandbox = false; // iOS: copying file to app sandbox
  int _timeTakenMs = 0;
  String _enhanceResolution = '4K (Ultra HD)';
  double _videoSharpness = 2.0;
  bool _enableHdr = true;
  bool _enableDenoise = true;

  Future<void> _pickVideo() async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _originalVideo = File(result.files.single.path!);
          _enhancedVideo = null;
          _progress = 0.0;
          _timeTakenMs = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _enhanceVideo() async {
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
      _isEnhancing = true;
      _progress = 0.0;
    });

    final stopwatch = Stopwatch()..start();

    // Listen to video processing progress
    final subscription = CompressService.videoProgressStream.listen((progress) {
      setState(() {
        _progress = progress;
      });
    });

    try {
      // Use highest video quality for maximum detail retention & resolution
      final enhanced = await CompressService.compressVideo(
        sourcePath: _originalVideo!.path,
        quality: VideoQuality.high,
      );

      stopwatch.stop();
      subscription.cancel();

      if (enhanced != null) {
        setState(() {
          _enhancedVideo = enhanced;
          _timeTakenMs = stopwatch.elapsedMilliseconds;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยกเลิกการเพิ่มความคมชัดวิดีโอแล้ว'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      subscription.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเพิ่มความคมชัดวิดีโอ: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isEnhancing = false;
      });
    }
  }

  void _resetVideo() {
    setState(() {
      _originalVideo = null;
      _enhancedVideo = null;
      _progress = 0.0;
      _timeTakenMs = 0;
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFD500F9), fontWeight: FontWeight.bold)),
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

  String _getSharpnessLabel(double val) {
    if (val == 1.0) return 'บางเบา (Mild)';
    if (val == 2.0) return 'มาตรฐาน (Normal)';
    if (val == 3.0) return 'ชัดเจน (Strong)';
    return 'สูงสุด (Ultra 4K)';
  }

  @override
  Widget build(BuildContext context) {
    final originalSize = _originalVideo?.lengthSync() ?? 0;
    final enhancedSize = _enhancedVideo?.lengthSync() ?? 0;

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
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                child: Column(
                  children: [
                    const LinearProgressIndicator(
                      color: Color(0xFFD500F9),
                      backgroundColor: Colors.white10,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'กำลังโหลดไฟล์วิดีโอ...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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
              title: 'เลือกวิดีโอเพื่อเพิ่มความคมชัด',
              subtitle: 'วิเคราะห์โครงสร้างคีย์เฟรมและเพิ่มรายละเอียดความละเอียดสูงสุด',
              icon: Icons.video_call_rounded,
              onTap: _pickVideo,
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
                        Icon(Icons.info_outline, color: Color(0xFFD500F9), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ฟังก์ชั่นเพิ่มความคมชัดวิดีโอคืออะไร?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD500F9)),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    const Text(
                      '1. ระบบจะวิเคราะห์โครงสร้างคีย์เฟรมเพื่อปรับระดับบิตเรตแบบไดนามิกพร้อมฟิลเตอร์ความคมชัดของภาพ',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '2. การเพิ่มพารามิเตอร์บิตเรตและพิกเซลจะช่วยแก้ไขส่วนที่เบลอเนื่องจากการบีบอัดมากเกินไป:',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint('ปรับโครงสร้างพิกเซลให้เรียบเนียนขึ้น'),
                          _buildBulletPoint('ประมวลผลวิดีโอแบบออฟไลน์ 100% ปลอดภัยอย่างแน่นอน'),
                          _buildBulletPoint('รองรับความคมชัดระดับ 4K Ultra HD & 2K QHD'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_enhancedVideo == null && !_isEnhancing) ...[
            // Video Details Card
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
                        const Icon(Icons.video_collection_outlined, color: Colors.purpleAccent, size: 20),
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
                                'iOS อาจแสดงขนาดไฟล์ต่างจากต้นฉบับ เนื่องจากการแปลง HEVC→H.264 โดยอัตโนมัติ',
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

            // Enhance settings card
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
                        Text(
                          'การตั้งค่าการปรับความคมชัดวิดีโอ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Resolution Dropdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ความละเอียดปลายทาง:', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF130E29).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _enhanceResolution,
                              dropdownColor: const Color(0xFF1A1435),
                              borderRadius: BorderRadius.circular(16),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00E5FF)),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: '4K (Ultra HD)', child: Text('4K (Ultra HD)')),
                                DropdownMenuItem(value: '2K (QHD)', child: Text('2K (QHD)')),
                                DropdownMenuItem(value: '1080p (Full HD)', child: Text('1080p (Full HD)')),
                                DropdownMenuItem(value: '720p (HD)', child: Text('720p (HD)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _enhanceResolution = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sharpness Slider
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ระดับความคมชัดเฟรม (Sharpness)',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getSharpnessLabel(_videoSharpness),
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
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
                      onChanged: (val) {
                        setState(() {
                          _videoSharpness = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Pro Video Filters (HDR & Denoise Toggles)
                    Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            label: const Text('HDR Color Boost'),
                            selected: _enableHdr,
                            labelStyle: TextStyle(
                              color: _enableHdr ? Colors.cyanAccent : Colors.white60,
                              fontSize: 11,
                              fontWeight: _enableHdr ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) => setState(() => _enableHdr = val),
                            selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                            checkmarkColor: Colors.cyanAccent,
                            backgroundColor: Colors.white.withOpacity(0.04),
                            side: BorderSide(color: _enableHdr ? const Color(0xFF00E5FF) : Colors.white12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilterChip(
                            label: const Text('Denoise & Smooth'),
                            selected: _enableDenoise,
                            labelStyle: TextStyle(
                              color: _enableDenoise ? Colors.cyanAccent : Colors.white60,
                              fontSize: 11,
                              fontWeight: _enableDenoise ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) => setState(() => _enableDenoise = val),
                            selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                            checkmarkColor: Colors.cyanAccent,
                            backgroundColor: Colors.white.withOpacity(0.04),
                            side: BorderSide(color: _enableDenoise ? const Color(0xFF00E5FF) : Colors.white12),
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
              onPressed: _enhanceVideo,
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
                      Icon(Icons.auto_awesome, color: Colors.white),
                      SizedBox(width: 8),
                      Text('เริ่มเพิ่มความคมชัดวิดีโอ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_isEnhancing) ...[
            // Progress Card
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
                        const Text(
                          'กำลังเพิ่มความคมชัดวิดีโอ...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        Text(
                          '${_progress.toStringAsFixed(0)}%',
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
                        value: _progress / 100,
                        color: const Color(0xFFD500F9),
                        backgroundColor: Colors.white10,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'การวิเคราะห์และประมวลผลพิกเซลแบบออฟไลน์\nโปรดอย่าปิดแอปพลิเคชัน',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
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
                  gradientColors: const [Color(0xFF00E5FF), Color(0xFFD500F9)],
                  shadowColor: const Color(0xFF00E5FF),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'เพิ่มความคมชัดสำเร็จแล้ว!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildStatRow('เวลาที่ใช้ประมวลผล:', '${(_timeTakenMs / 1000).toStringAsFixed(1)} วินาที'),
                        const SizedBox(height: 10),
                        _buildStatRow('ระดับความละเอียดปลายทาง:', _enhanceResolution),
                        _buildStatRow('ขนาดไฟล์ปลายทาง:', CompressService.formatBytes(enhancedSize)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                VideoPreviewWidget(
                  file: _enhancedVideo!,
                  title: 'ตัวอย่างวิดีโอที่เพิ่มความคมชัดแล้ว:',
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () => MediaUtility.openFile(_enhancedVideo!),
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
                        onPressed: () => MediaUtility.saveToGallery(context, _enhancedVideo!, isVideo: true),
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
                        onPressed: () => MediaUtility.shareFile(_enhancedVideo!, 'enhanced_video.mp4'),
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
                  child: const Text('เพิ่มความคมชัดวิดีโออื่น', style: TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
