import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewWidget extends StatefulWidget {
  final File file;
  final String title;

  // Max file size to attempt preview (300MB). Above this, skip AVPlayer init
  // to prevent iOS Jetsam (OOM kill) on large video files.
  static const int _previewMaxBytes = 300 * 1024 * 1024; // 300MB

  const VideoPreviewWidget({
    super.key,
    required this.file,
    required this.title,
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _fileTooLarge = false;
  int _fileSize = 0;

  @override
  void initState() {
    super.initState();
    _checkAndInitialize();
  }

  @override
  void didUpdateWidget(covariant VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _fileTooLarge = false;
      _checkAndInitialize();
    }
  }

  Future<void> _checkAndInitialize() async {
    try {
      final size = await widget.file.length();
      if (!mounted) return;

      setState(() {
        _fileSize = size;
        _fileTooLarge = size > VideoPreviewWidget._previewMaxBytes;
      });

      // Only attempt AVPlayer init for files ≤ 300MB to protect iOS from OOM
      if (!_fileTooLarge) {
        await _initializeController();
      }
    } catch (e) {
      debugPrint('Error checking file size: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _initializeController() async {
    try {
      _controller = VideoPlayerController.file(widget.file);
      await _controller!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout loading video preview');
        },
      );
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    // File too large — skip preview entirely, show info card instead
    if (_fileTooLarge) {
      return _buildLargeFilePlaceholder();
    }

    if (_hasError) {
      return _buildErrorPlaceholder();
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              ),
              SizedBox(height: 16),
              Text(
                'กำลังโหลดตัวอย่างวิดีโอ...',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final duration = _controller!.value.duration;
    final position = _controller!.value.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _controller!.value.isPlaying
                          ? Colors.transparent
                          : Colors.black.withAlpha(100),
                    ),
                    child: _controller!.value.isPlaying
                        ? const SizedBox.shrink()
                        : const Center(
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.purpleAccent,
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _controller!.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          });
                        },
                      ),
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          _controller!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.purpleAccent,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white10,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeFilePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A0A2E).withOpacity(0.9),
            const Color(0xFF0D0D1A).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD500F9).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFD500F9).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.movie_rounded, color: Color(0xFFD500F9), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'ไฟล์ขนาดใหญ่ — ข้ามการแสดงตัวอย่าง',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ขนาดไฟล์: ${_formatBytes(_fileSize)}\n'
            'ไฟล์ที่มีขนาดเกิน 300MB จะข้ามการแสดงตัวอย่างเพื่อป้องกัน\n'
            'แอปปิดกะทันหันบน iOS (Memory Limit)\n'
            'คุณสามารถบีบอัด บันทึก หรือแชร์ไฟล์ได้ตามปกติ',
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.orangeAccent, size: 36),
            SizedBox(height: 8),
            Text(
              'ไม่สามารถแสดงตัวอย่างวิดีโอนี้ได้',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'สามารถกดบันทึกหรือแชร์ไฟล์ได้ตามปกติ',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
