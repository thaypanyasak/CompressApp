import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// ระดับความละเอียดปลายทางสำหรับการขยายวิดีโอ (upscale)
class EnhanceResolution {
  final String label;
  final int width;
  final int height;
  const EnhanceResolution(this.label, this.width, this.height);

  static const auto = EnhanceResolution('ตามไฟล์ต้นฉบับ', 0, 0);
  static const hd720 = EnhanceResolution('720p (HD)', 1280, 720);
  static const fhd1080 = EnhanceResolution('1080p (Full HD)', 1920, 1080);
  static const qhd2k = EnhanceResolution('2K (QHD)', 2560, 1440);
  static const uhd4k = EnhanceResolution('4K (Ultra HD)', 3840, 2160);

  static const values = [uhd4k, qhd2k, fhd1080, hd720, auto];
}

/// Tham số xử lý enhance video
class VideoEnhanceParams {
  final String sourcePath;
  final String outputPath;
  final EnhanceResolution resolution; // auto = giữ nguyên
  final double sharpness; // 1..4 (level)
  final bool enableDenoise;
  final bool enableHdr;
  final int fps; // 0 = giữ nguyên, 30/60/120 = mục tiêu
  final int? bitrateKbps; // null = tự động

  VideoEnhanceParams({
    required this.sourcePath,
    required this.outputPath,
    this.resolution = EnhanceResolution.auto,
    this.sharpness = 1.0,
    this.enableDenoise = false,
    this.enableHdr = false,
    this.fps = 0,
    this.bitrateKbps,
  });

  bool get needsFpsSmooth => fps > 0;
}

class VideoEnhanceResult {
  final String path;
  final int originalWidth;
  final int originalHeight;
  final int enhancedWidth;
  final int enhancedHeight;
  final double originalFps;
  final double enhancedFps;
  final double durationSeconds;
  final int fileSize;

  VideoEnhanceResult({
    required this.path,
    required this.originalWidth,
    required this.originalHeight,
    required this.enhancedWidth,
    required this.enhancedHeight,
    required this.originalFps,
    required this.enhancedFps,
    required this.durationSeconds,
    required this.fileSize,
  });
}

class VideoEnhanceCancelled implements Exception {
  const VideoEnhanceCancelled();
  @override
  String toString() => 'Đã hủy xử lý video';
}

/// Trạng thái thông tin video probe được
class VideoProbe {
  final double fps;
  final int width;
  final int height;
  final double duration;
  const VideoProbe({
    required this.fps,
    required this.width,
    required this.height,
    required this.duration,
  });
}

class VideoEnhanceService {
  VideoEnhanceService._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    FFmpegKitConfig.enableLogCallback((log) {
      debugPrint('FFmpeg: ${log.getMessage()}');
    });
  }

  /// Đọc thông tin video tổng hợp (fps, resolution, duration) bằng FFprobe
  static Future<VideoProbe> probeVideo(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info == null) {
        return const VideoProbe(fps: 0, width: 0, height: 0, duration: 0);
      }
      double duration = double.tryParse(info.getDuration() ?? '') ?? 0;
      double fps = 0;
      int width = 0;
      int height = 0;
      final streams = info.getStreams();
      for (final s in streams) {
        if (s.getType() == 'video') {
          final w = s.getWidth();
          final h = s.getHeight();
          if (w != null && w > 0) width = w;
          if (h != null && h > 0) height = h;
          final af = _parseFps(s.getAverageFrameRate());
          if (af > 0) fps = af;
          if (fps == 0) fps = _parseFps(s.getRealFrameRate());
        }
      }
      return VideoProbe(
        fps: fps,
        width: width,
        height: height,
        duration: duration,
      );
    } catch (e) {
      debugPrint('FFprobe lỗi: $e');
      return const VideoProbe(fps: 0, width: 0, height: 0, duration: 0);
    }
  }

  /// E.g. "30000/1001" or "30" → 30.0
  static double _parseFps(String? value) {
    if (value == null || value.isEmpty) return 0;
    final parts = value.split('/');
    double result = 0;
    try {
      if (parts.length == 2) {
        final num = double.parse(parts[0].trim());
        final den = double.parse(parts[1].trim());
        if (den != 0 && num > 0) result = num / den;
      } else {
        result = double.parse(value.trim());
      }
    } catch (_) {
      result = 0;
    }
    return result;
  }

  static Future<void> cancelAll() async {
    await FFmpegKit.cancel();
  }

  /// Tạo file mới trong temp dir cho output
  static Future<String> makeOutputPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }

  /// Xử lý enhance video bằng FFmpeg với các filter thật:
  /// - denoise (hqdn3d)
  /// - upscale (scale + lanczos)
  /// - sharpness (unsharp)
  /// - HDR (eq)
  /// - FPS smoothing (minterpolate - nội suy chuyển động)
  ///
  /// Trả về kết quả và báo tiến trình 0→1 qua [onProgress].
  static Future<VideoEnhanceResult> enhanceVideo(
    VideoEnhanceParams params, {
    void Function(double progress)? onProgress,
  }) async {
    ensureInitialized();

    final input = params.sourcePath;

    // Probe thông tin nguồn để tính tiến trình chính xác
    final src = await probeVideo(input);
    final srcFps = src.fps;
    final srcResW = src.width;
    final srcResH = src.height;
    final durationMs = (src.duration * 1000).round();

    debugPrint(
      'Nguồn: ${srcResW}x${srcResH}, fps=$srcFps, dur=${src.duration}s',
    );

    // ── Xây dựng filter chain ──────────────────────────────────────────────
    final filters = <String>[];

    // 1. Denoise trước (khử nhiễu hạt)
    if (params.enableDenoise) {
      filters.add('hqdn3d=1.5:1.5:6:6');
    }

    // 2. Upscale theo resolution mong muốn (chỉ khi khác auto)
    if (params.resolution.width > 0) {
      final targetW = params.resolution.width;
      final targetH = params.resolution.height;
      // Chỉ upscale nếu nguồn nhỏ hơn target (không giảm chất lượng)
      final needsUpscale =
          (srcResW == 0 || srcResH == 0) ||
          (srcResW < targetW && srcResH < targetH);
      if (needsUpscale) {
        filters.add(
          'scale=$targetW:$targetH:force_original_aspect_ratio=decrease:flags=lanczos',
        );
        // Kích thước chẵn cho H.264
        filters.add('scale=trunc(iw/2)*2:trunc(ih/2)*2');
      }
    }

    // 3. Sharpness (unsharp) — level 1..4 → amount tăng dần
    if (params.sharpness > 0) {
      final amount = (0.6 + (params.sharpness - 1.0) * 0.45).toStringAsFixed(2);
      final radius = params.sharpness >= 3.0 ? 2 : 1;
      filters.add('unsharp=5:$radius:$amount:5:5:0.0');
    }

    // 4. HDR color boost
    if (params.enableHdr) {
      filters.add('eq=contrast=1.15:saturation=1.12:brightness=0.02:gamma=1.1');
    }

    // 5. FPS smoothing (minterpolate nội suy chuyển động)
    // minterpolate tăng fps theo hệ số 2 mỗi pass; ta xâu chuỗi để đạt target.
    bool fpsHandled = false;
    if (params.needsFpsSmooth && srcFps > 0) {
      final targetFps = params.fps;
      int passes = 0;
      double currentFps = srcFps;
      while (currentFps < targetFps && passes < 5) {
        currentFps *= 2;
        passes++;
      }
      for (int i = 0; i < passes; i++) {
        filters.add(
          'minterpolate=fps=${currentFps.toInt()}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsync=vfr',
        );
      }
      // Kẹp đúng target bằng filter fps
      filters.add('fps=$targetFps');
      fpsHandled = true;
    }

    final filterChain = filters.join(',');

    // ── Dựng lệnh ──────────────────────────────────────────────────────────
    final cmd = StringBuffer();
    cmd
      ..write('-y -i ')
      ..write(_quote(input));

    if (filterChain.isNotEmpty) {
      cmd
        ..write(' -vf ')
        ..write(_quote(filterChain));
    }

    cmd
      ..write(' -c:v libx264 -preset slow -crf 18')
      ..write(' -pix_fmt yuv420p')
      ..write(' -c:a aac -b:a 128k');

    if (fpsHandled) {
      cmd.write(' -vsync 2');
    }

    cmd
      ..write(' ')
      ..write(_quote(params.outputPath));

    final command = cmd.toString();
    debugPrint('FFmpeg command: $command');

    // ── Thực thi ────────────────────────────────────────────────────────────
    final completer = Completer<VideoEnhanceResult>();
    final outputFile = File(params.outputPath);

    try {
      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode) && await outputFile.exists()) {
            final out = await probeVideo(params.outputPath);
            if (onProgress != null) onProgress(1.0);
            completer.complete(
              VideoEnhanceResult(
                path: params.outputPath,
                originalWidth: srcResW,
                originalHeight: srcResH,
                enhancedWidth: out.width,
                enhancedHeight: out.height,
                originalFps: srcFps,
                enhancedFps: out.fps,
                durationSeconds: out.duration,
                fileSize: await outputFile.length(),
              ),
            );
          } else if (ReturnCode.isCancel(returnCode)) {
            completer.completeError(const VideoEnhanceCancelled());
          } else {
            final logs = await session.getOutput();
            debugPrint('FFmpeg lỗi: $logs');
            completer.completeError(
              Exception('Lỗi xử lý video bằng FFmpeg: $logs'),
            );
          }
        },
        null,
        (stats) {
          if (onProgress == null) return;
          final t = stats.getTime(); // double, micro giây
          if (t <= 0 || durationMs <= 0) return;
          var ms = (t / 1000).round();
          if (ms > durationMs) ms = durationMs;
          final p = (ms / durationMs).clamp(0.0, 1.0);
          onProgress(p);
        },
      );
    } on VideoEnhanceCancelled {
      rethrow;
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  static String _quote(String path) {
    return '"${path.replaceAll('\\', '/')}"';
  }
}
