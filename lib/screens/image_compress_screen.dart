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

class _ImageCompressScreenState extends State<ImageCompressScreen> {
  File? _originalImage;
  File? _compressedImage;
  double _imageQuality = 80.0;
  CompressFormat _imageFormat = CompressFormat.jpeg;
  String _imageResolutionLimit = 'Original';
  bool _isImageCompressing = false;
  double _imageProgress = 0.0;
  Timer? _progressTimer;
  int _imageTimeTakenMs = 0;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      allowCompression: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _originalImage = File(result.files.single.path!);
        _compressedImage = null;
        _imageTimeTakenMs = 0;
      });
    }
  }

  void _startProgressSimulation() {
    _imageProgress = 0.0;
    _progressTimer?.cancel();
    // Simulate progress: fast to 85%, then hold until done
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_imageProgress < 85.0) {
          _imageProgress += (85.0 - _imageProgress) * 0.04 + 0.3;
        } else if (_imageProgress < 92.0) {
          _imageProgress += 0.08;
        }
        _imageProgress = _imageProgress.clamp(0.0, 92.0);
      });
    });
  }

  void _finishProgress() {
    _progressTimer?.cancel();
    if (mounted) setState(() => _imageProgress = 100.0);
  }

  Future<void> _compressImage() async {
    if (_originalImage == null) return;

    setState(() {
      _isImageCompressing = true;
      _imageProgress = 0.0;
    });
    _startProgressSimulation();

    final stopwatch = Stopwatch()..start();

    try {
      int? minWidth;
      int? minHeight;

      if (_imageResolutionLimit == '1080p') {
        minWidth = 1920;
        minHeight = 1080;
      } else if (_imageResolutionLimit == '720p') {
        minWidth = 1280;
        minHeight = 720;
      }

      final compressed = await CompressService.compressImage(
        sourcePath: _originalImage!.path,
        quality: _imageQuality.toInt(),
        minWidth: minWidth,
        minHeight: minHeight,
        format: _imageFormat,
      );

      stopwatch.stop();
      _finishProgress();

      await Future.delayed(const Duration(milliseconds: 300));

      if (compressed != null && mounted) {
        setState(() {
          _compressedImage = compressed;
          _imageTimeTakenMs = stopwatch.elapsedMilliseconds;
        });
      }
    } catch (e) {
      _finishProgress();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบีบอัดรูปภาพ: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImageCompressing = false);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _resetImage() {
    _progressTimer?.cancel();
    setState(() {
      _originalImage = null;
      _compressedImage = null;
      _imageProgress = 0.0;
      _imageTimeTakenMs = 0;
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

  @override
  Widget build(BuildContext context) {
    final originalSize = _originalImage?.lengthSync() ?? 0;
    final compressedSize = _compressedImage?.lengthSync() ?? 0;
    final reduction = CompressService.getReductionPercentage(originalSize, compressedSize);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_originalImage == null) ...[
            GlowPickerArea(
              title: 'เลือกรูปภาพเพื่อบีบอัด',
              subtitle: 'บีบอัดรูปภาพออฟไลน์ด่วนรักษาความคมชัด',
              icon: Icons.add_photo_alternate_rounded,
              onTap: _pickImage,
              gradientColors: const [Color(0xFFE040FB), Color(0xFF00E5FF)],
            ),
          ] else if (_compressedImage == null) ...[
            // Original Image Card
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
                        const Expanded(
                          child: Text(
                            'รายละเอียดไฟล์ภาพ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white60),
                          onPressed: _resetImage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow('ชื่อไฟล์:', _originalImage!.path.split(Platform.pathSeparator).last),
                    const SizedBox(height: 8),
                    _buildStatRow('ขนาดเดิม:', CompressService.formatBytes(originalSize)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Settings Card
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
                          'ตัวเลือกการบีบอัด',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quality slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('คุณภาพของรูปภาพ:', style: TextStyle(color: Colors.white70)),
                        Text('${_imageQuality.toInt()}%', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _imageQuality,
                      min: 10,
                      max: 100,
                      divisions: 90,
                      activeColor: const Color(0xFF00E5FF),
                      inactiveColor: Colors.white10,
                      onChanged: (val) {
                        setState(() {
                          _imageQuality = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Output Format Selection
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
                                DropdownMenuItem(value: CompressFormat.png, child: Text('PNG (ไม่สูญเสียรายละเอียด)')),
                                DropdownMenuItem(value: CompressFormat.webp, child: Text('WEBP (แนะนำ)')),
                                DropdownMenuItem(value: CompressFormat.heic, child: Text('HEIC (คุณภาพสูง)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _imageFormat = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Max Resolution limit selection
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
                                DropdownMenuItem(value: '1080p', child: Text('สูงสุด 1080p (Full HD)')),
                                DropdownMenuItem(value: '720p', child: Text('สูงสุด 720p (HD)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _imageResolutionLimit = val;
                                  });
                                }
                              },
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

            if (_isImageCompressing) ...[
              GlowingContainer(
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
                          const Text(
                            'กำลังบีบอัดรูปภาพ...',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          Text(
                            '${_imageProgress.toStringAsFixed(0)}%',
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
                          value: _imageProgress / 100,
                          color: const Color(0xFF00E5FF),
                          backgroundColor: Colors.white10,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ประมวลผลบนเครื่องแบบ Offline 100%\nโปรดอย่าปิดแอปพลิเคชัน',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _compressImage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                  shadowColor: const Color(0xFF8E2DE2).withOpacity(0.5),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
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
                        Icon(Icons.compress, color: Colors.white),
                        SizedBox(width: 8),
                        Text('เริ่มบีบอัดรูปภาพ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ] else ...[
            // Show compression result
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
                                  'ผลลัพธ์การบีบอัด',
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
                        _buildStatRow('เวลาที่ใช้ในการประมวลผล:', '${(_imageTimeTakenMs / 1000).toStringAsFixed(2)} วินาที'),
                        const SizedBox(height: 10),
                        _buildStatRow('ตำแหน่งที่บันทึก:', 'แคชออฟไลน์ (Offline Cache)'),
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
                const SizedBox(height: 20),

                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text('เปรียบเทียบรูปภาพ (ลาก thanh trượt để xem)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ),
                BeforeAfterSlider(
                  beforeImage: _originalImage!,
                  afterImage: _compressedImage!,
                  height: 580,
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () => MediaUtility.openFile(_compressedImage!),
                  icon: const Icon(Icons.visibility),
                  label: const Text('ดูรูปภาพเต็ม'),
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
                        onPressed: () => MediaUtility.saveToGallery(context, _compressedImage!, isVideo: false),
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
                        onPressed: () => MediaUtility.shareFile(_compressedImage!, 'compressed_image.jpg'),
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
                  onPressed: _resetImage,
                  child: const Text('บีบอัดภาพอื่น', style: TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
