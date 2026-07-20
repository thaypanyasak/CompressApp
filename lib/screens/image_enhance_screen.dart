import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

class _ImageEnhanceScreenState extends State<ImageEnhanceScreen> {
  File? _originalEnhanceImage;
  File? _enhancedImage;
  double _enhanceSharpness = 2.0;
  double _enhanceUpscaleFactor = 2.0;
  bool _enableHdr = true;
  bool _enableDenoise = true;
  bool _isImageEnhancing = false;
  double _enhanceProgress = 0.0;
  Timer? _enhanceProgressTimer;
  int _enhanceTimeTakenMs = 0;
  String? _originalResolution;
  String? _enhancedResolution;

  Future<void> _pickEnhanceImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      
      try {
        final bytes = await file.readAsBytes();
        final imgObj = img.decodeImage(bytes);
        if (imgObj != null) {
          setState(() {
            _originalEnhanceImage = file;
            _enhancedImage = null;
            _enhanceTimeTakenMs = 0;
            _originalResolution = '${imgObj.width} x ${imgObj.height}';
            _enhancedResolution = null;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _originalEnhanceImage = file;
        _enhancedImage = null;
        _enhanceTimeTakenMs = 0;
        _originalResolution = 'ไม่ทราบแน่ชัด';
        _enhancedResolution = null;
      });
    }
  }

  void _startEnhanceProgressSimulation() {
    _enhanceProgress = 0.0;
    _enhanceProgressTimer?.cancel();
    _enhanceProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_enhanceProgress < 80.0) {
          _enhanceProgress += (80.0 - _enhanceProgress) * 0.03 + 0.5;
        } else if (_enhanceProgress < 90.0) {
          _enhanceProgress += 0.1;
        }
        _enhanceProgress = _enhanceProgress.clamp(0.0, 90.0);
      });
    });
  }

  void _finishEnhanceProgress() {
    _enhanceProgressTimer?.cancel();
    if (mounted) setState(() => _enhanceProgress = 100.0);
  }

  @override
  void dispose() {
    _enhanceProgressTimer?.cancel();
    super.dispose();
  }

  Future<void> _enhanceImage() async {
    if (_originalEnhanceImage == null) return;

    setState(() {
      _isImageEnhancing = true;
      _enhanceProgress = 0.0;
    });
    _startEnhanceProgressSimulation();

    final stopwatch = Stopwatch()..start();

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}${Platform.pathSeparator}enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final params = ImageEnhanceParams(
        sourcePath: _originalEnhanceImage!.path,
        outputPath: outputPath,
        upscaleFactor: _enhanceUpscaleFactor,
        sharpnessLevel: _enhanceSharpness,
        enableHdr: _enableHdr,
        enableDenoise: _enableDenoise,
      );

      final result = await compute(enhanceImageWork, params);

      stopwatch.stop();
      _finishEnhanceProgress();
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _enhancedImage = File(result.path);
          _enhanceTimeTakenMs = stopwatch.elapsedMilliseconds;
          _enhancedResolution = '${result.enhancedWidth} x ${result.enhancedHeight}';
        });
      }
    } catch (e) {
      _finishEnhanceProgress();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImageEnhancing = false);
    }
  }

  void _resetEnhanceImage() {
    _enhanceProgressTimer?.cancel();
    setState(() {
      _originalEnhanceImage = null;
      _enhancedImage = null;
      _enhanceProgress = 0.0;
      _enhanceTimeTakenMs = 0;
      _originalResolution = null;
      _enhancedResolution = null;
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

  Widget _buildUpscalePill(double factor, String label) {
    final isSelected = _enhanceUpscaleFactor == factor;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _enhanceUpscaleFactor = factor;
          });
        },
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

  String _getSharpnessLabel(double val) {
    if (val == 1.0) return 'บางเบา (Mild)';
    if (val == 2.0) return 'มาตรฐาน (Normal)';
    if (val == 3.0) return 'ชัดเจน (Strong)';
    return 'สูงสุด (Ultra 4K)';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_originalEnhanceImage == null) ...[
            GlowPickerArea(
              title: 'เลือกรูปภาพเพื่อเพิ่มความคมชัด',
              subtitle: 'รองรับไฟล์ JPG, PNG (ประมวลผลออฟไลน์ 100%)',
              icon: Icons.auto_awesome_motion_rounded,
              onTap: _pickEnhanceImage,
              gradientColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
            ),
          ] else ...[
            // Image Preview & Settings
            GlowingContainer(
              gradientColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
              shadowColor: const Color(0xFF00E5FF),
              borderRadius: 24,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_size_select_actual_outlined, color: Colors.cyanAccent, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'ภาพต้นฉบับ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white60),
                          onPressed: _resetEnhanceImage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.black26,
                        child: Image.file(
                          _originalEnhanceImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow('ขนาดไฟล์:', CompressService.formatBytes(_originalEnhanceImage!.lengthSync())),
                    _buildStatRow('ความละเอียด:', _originalResolution ?? 'ไม่ทราบ'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Enhance Options
            if (_enhancedImage == null && !_isImageEnhancing) ...[
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
                          Text(
                            'ตั้งค่าการเพิ่มความละเอียดระดับ 4K',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Upscale Options
                      const Text(
                        'ระดับการขยายความละเอียด (Upscale)',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
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

                      // Sharpness Options Header
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'ระดับความคมชัด (Sharpness)',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD500F9).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getSharpnessLabel(_enhanceSharpness),
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _enhanceSharpness,
                        min: 1.0,
                        max: 4.0,
                        divisions: 3,
                        activeColor: const Color(0xFFD500F9),
                        inactiveColor: Colors.white10,
                        onChanged: (val) {
                          setState(() {
                            _enhanceSharpness = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Pro Enhancements (HDR & Denoise Toggles)
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
                              labelStyle: TextStyle(
                                color: _enableDenoise ? Colors.cyanAccent : Colors.white60,
                                fontSize: 11,
                                fontWeight: _enableDenoise ? FontWeight.bold : FontWeight.normal,
                              ),
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
                        onPressed: _enhanceImage,
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        label: const Text(
                          'เริ่มประมวลผลเพิ่มความคมชัด',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

            // Processing Loader
            if (_isImageEnhancing) ...[
              const SizedBox(height: 20),
              GlowingContainer(
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
                          const Text(
                            'กำลังเพิ่มความคมชัด 4K...',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          Text(
                            '${_enhanceProgress.toStringAsFixed(0)}%',
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
                          value: _enhanceProgress / 100,
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
            ],

            // Enhanced Result Card
            if (_enhancedImage != null && !_isImageEnhancing) ...[
              const SizedBox(height: 20),
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
                          Text(
                            'เพิ่มความคมชัดเรียบร้อยแล้ว!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BeforeAfterSlider(
                        beforeImage: _originalEnhanceImage!,
                        afterImage: _enhancedImage!,
                        height: 580,
                      ),
                      const SizedBox(height: 20),
                      
                      const Text(
                        'เปรียบเทียบข้อมูลภาพ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow('ความละเอียดต้นฉบับ:', _originalResolution ?? ''),
                      _buildStatRow('ความละเอียดใหม่:', _enhancedResolution ?? '', highlight: true),
                      _buildStatRow('ขนาดไฟล์ใหม่:', CompressService.formatBytes(_enhancedImage!.lengthSync())),
                      _buildStatRow('เวลาที่ใช้ประมวลผล:', '${(_enhanceTimeTakenMs / 1000).toStringAsFixed(2)} วินาที'),
                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: () => MediaUtility.openFile(_enhancedImage!),
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
                              onPressed: () => MediaUtility.saveToGallery(context, _enhancedImage!, isVideo: false),
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
                              onPressed: () => MediaUtility.shareFile(_enhancedImage!, 'enhanced_image.jpg'),
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
                        onPressed: _resetEnhanceImage,
                        child: const Text('เพิ่มความคมชัดรูปภาพอื่น', style: TextStyle(color: Colors.cyanAccent)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
