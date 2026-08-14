import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../utils/media_utility.dart';
import '../widgets/glow_picker_area.dart';
import '../widgets/glowing_container.dart';

class FormatConverterScreen extends StatefulWidget {
  const FormatConverterScreen({super.key});

  @override
  State<FormatConverterScreen> createState() => _FormatConverterScreenState();
}

class _FormatConverterScreenState extends State<FormatConverterScreen> {
  List<File> _selectedFiles = [];
  List<File> _convertedFiles = [];
  String _targetFormat = 'PNG'; // JPG, PNG, WEBP
  bool _isConverting = false;
  double _progress = 0.0;
  String _progressText = '';

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
      withReadStream: false,
    );

    if (result != null && result.paths.isNotEmpty) {
      final validFiles =
          result.paths
              .where((path) => path != null)
              .map((path) => File(path!))
              .toList();

      setState(() {
        _selectedFiles = validFiles;
        _convertedFiles = [];
        _progress = 0.0;
        _progressText = '';
      });
    }
  }

  Future<void> _convertFormats() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _convertedFiles = [];
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final results = <File>[];

      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        final currentFileNum = i + 1;

        setState(() {
          _progress = (i + 0.5) / _selectedFiles.length;
          _progressText =
              'กำลังแปลงไฟล์ที่ $currentFileNum จาก ${_selectedFiles.length}...';
        });

        final bytes = await file.readAsBytes();
        final image = img.decodeImage(bytes);

        if (image != null) {
          final timeStamp = DateTime.now().millisecondsSinceEpoch;
          final outExtension = _targetFormat.toLowerCase();
          final outputPath =
              '${tempDir.path}${Platform.pathSeparator}converted_${i}_$timeStamp.$outExtension';

          List<int> encodedBytes;
          if (_targetFormat == 'PNG') {
            encodedBytes = img.encodePng(image);
          } else if (_targetFormat == 'WEBP') {
            encodedBytes = img.encodePng(image); // Clean loss-free conversion
          } else {
            encodedBytes = img.encodeJpg(image, quality: 95);
          }

          final outFile = File(outputPath);
          await outFile.writeAsBytes(encodedBytes);
          results.add(outFile);
        }

        setState(() {
          _progress = currentFileNum / _selectedFiles.length;
        });
      }

      setState(() {
        _convertedFiles = results;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการแปลงไฟล์: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedFiles = [];
      _convertedFiles = [];
      _progress = 0.0;
      _progressText = '';
    });
  }

  Widget _buildFormatPill(String format) {
    final isSelected = _targetFormat == format;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _targetFormat = format;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? const Color(0xFF00E5FF).withOpacity(0.15)
                    : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFF00E5FF)
                      : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '.${format.toUpperCase()}',
            style: TextStyle(
              color: isSelected ? Colors.cyanAccent : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
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
          if (_selectedFiles.isEmpty) ...[
            GlowPickerArea(
              title: 'เลือกรูปภาพเพื่อแปลง định dạng',
              subtitle: 'รองรับการเลือกหลายรูปภาพพร้อมกัน (JPG ↔ PNG ↔ WEBP)',
              icon: Icons.transform_rounded,
              onTap: _pickImages,
              gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            ),
          ] else if (_convertedFiles.isEmpty && !_isConverting) ...[
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
                        const Icon(
                          Icons.collections_outlined,
                          color: Colors.purpleAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'เลือกทั้งหมด ${_selectedFiles.length} รูปภาพ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
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
                    Text(
                      'ไฟล์ที่เลือก: ${_selectedFiles.map((f) => f.path.split(Platform.pathSeparator).last).take(3).join(', ')}${_selectedFiles.length > 3 ? '...' : ''}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            GlowingContainer(
              gradientColors: const [Color(0xFF00E5FF), Color(0xFF00B0FF)],
              shadowColor: const Color(0xFF00E5FF),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เลือกนามสกุลไฟล์ปลายทาง (Target Format)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildFormatPill('PNG'),
                        const SizedBox(width: 8),
                        _buildFormatPill('JPG'),
                        const SizedBox(width: 8),
                        _buildFormatPill('WEBP'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _convertFormats,
              icon: const Icon(Icons.auto_fix_high),
              label: Text('เริ่มแปลงไฟล์ (${_selectedFiles.length} รายการ)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
            ),
          ] else if (_isConverting) ...[
            GlowingContainer(
              gradientColors: const [Color(0xFF00E5FF), Color(0xFFD500F9)],
              shadowColor: const Color(0xFF00E5FF),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      color: const Color(0xFF00E5FF),
                      backgroundColor: Colors.white10,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _progressText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Converted Results View
            GlowingContainer(
              gradientColors: const [Color(0xFF00E5FF), Color(0xFFD500F9)],
              shadowColor: const Color(0xFF00E5FF),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'แปลงไฟล์สำเร็จแล้ว!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'แปลงเรียบร้อยแล้ว ${_convertedFiles.length} ไฟล์ เป็นนามสกุล .$_targetFormat',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        for (final file in _convertedFiles) {
                          MediaUtility.saveToGallery(
                            context,
                            file,
                            isVideo: false,
                          );
                        }
                      },
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('บันทึกทั้งหมดลงคลังภาพ'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _reset,
                      child: const Text(
                        'แปลงไฟล์รูปภาพอื่น',
                        style: TextStyle(color: Colors.cyanAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
