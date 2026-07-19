import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import 'package:path_provider/path_provider.dart';

class CompressService {
  static final LightCompressor _videoCompressor = LightCompressor();

  /// Stream to listen for real-time video compression progress
  static Stream<double> get videoProgressStream => _videoCompressor.onProgressUpdated;

  /// Compress image offline with configurable quality (1-100)
  /// Returns the compressed [File], or null if compression was failed/canceled.
  static Future<File?> compressImage({
    required String sourcePath,
    required int quality,
    int? minWidth,
    int? minHeight,
    CompressFormat format = CompressFormat.jpeg,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final extension = _getExtensionForFormat(format);
      final targetPath = '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: quality,
        minWidth: minWidth ?? 1920,
        minHeight: minHeight ?? 1080,
        format: format,
      );

      if (compressedXFile != null) {
        return File(compressedXFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      rethrow;
    }
  }

  /// Compress video offline using hardware acceleration
  /// Returns the compressed [File], or null if canceled.
  static Future<File?> compressVideo({
    required String sourcePath,
    required VideoQuality quality,
    bool isMinBitrateCheckEnabled = false,
  }) async {
    try {
      final String videoName = 'vid_${DateTime.now().millisecondsSinceEpoch}';

      final Result result = await _videoCompressor.compressVideo(
        path: sourcePath,
        videoQuality: quality,
        isMinBitrateCheckEnabled: isMinBitrateCheckEnabled,
        video: Video(videoName: videoName),
        android: AndroidConfig(isSharedStorage: false), // internal cache so we can preview first
        ios: IOSConfig(saveInGallery: false), // internal cache so we can preview first
      );

      if (result is OnSuccess) {
        return File(result.destinationPath);
      } else if (result is OnFailure) {
        throw Exception(result.message);
      } else if (result is OnCancelled) {
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error compressing video: $e');
      rethrow;
    }
  }

  /// Cancel current active video compression
  static Future<void> cancelVideoCompression() async {
    await _videoCompressor.cancelCompression();
  }

  /// Format file size into a human-readable string (B, KB, MB, GB)
  static String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Get percentage reduction
  static double getReductionPercentage(int originalSize, int compressedSize) {
    if (originalSize <= 0) return 0.0;
    final reduction = ((originalSize - compressedSize) / originalSize) * 100;
    return reduction < 0 ? 0.0 : reduction;
  }

  static String _getExtensionForFormat(CompressFormat format) {
    switch (format) {
      case CompressFormat.jpeg:
        return 'jpg';
      case CompressFormat.png:
        return 'png';
      case CompressFormat.webp:
        return 'webp';
      case CompressFormat.heic:
        return 'heic';
    }
  }
}
