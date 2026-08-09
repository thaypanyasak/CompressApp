import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import 'package:path_provider/path_provider.dart';

class CompressService {
  static final LightCompressor _videoCompressor = LightCompressor();

  /// Stream to listen to real-time video compression progress
  static Stream<double> get videoProgressStream => _videoCompressor.onProgressUpdated;

  /// Reset or cancel current video compression
  static Future<void> resetVideoCompress() async {
    try {
      await _videoCompressor.cancelCompression();
    } catch (_) {}
  }

  /// Calculate total size of all cached files (temp dir + app documents)
  static Future<int> getCacheSize() async {
    int total = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      total += await _dirSize(tempDir);
    } catch (_) {}
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      total += await _dirSize(docsDir);
    } catch (_) {}
    return total;
  }

  static Future<int> _dirSize(Directory dir) async {
    int size = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try { size += await entity.length(); } catch (_) {}
      }
    }
    return size;
  }

  /// Delete all cached files in temp and documents directories
  static Future<void> clearAllCache() async {
    try {
      await resetVideoCompress();
    } catch (_) {}
    await _clearDir(await getTemporaryDirectory());
    await _clearDir(await getApplicationDocumentsDirectory());
  }

  static Future<void> _clearDir(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: false)) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// On iOS, FilePicker returns a sandboxed temp URL from the Photos framework
  /// that can be revoked by the OS once the app starts heavy memory usage.
  /// This method copies the file to the app's own Documents directory to ensure
  /// persistent read access throughout the entire compression process.
  static Future<File> ensureLocalVideoPath(String sourcePath, {void Function(double)? onProgress}) async {
    final srcFile = File(sourcePath);

    if (!Platform.isIOS) return srcFile;

    // Check if already inside the app's own sandbox
    final docsDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();

    if (sourcePath.startsWith(docsDir.path) ||
        sourcePath.startsWith(tempDir.path)) {
      debugPrint('CompressService: Path already in sandbox, skipping copy');
      if (onProgress != null) onProgress(1.0);
      return srcFile;
    }

    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'mp4';
    final destPath =
        '${docsDir.path}/input_${DateTime.now().millisecondsSinceEpoch}.$ext';

    debugPrint('CompressService: Copying video to sandbox: $destPath');
    
    if (onProgress != null) {
      final input = srcFile.openRead();
      final output = File(destPath).openWrite();
      final totalLength = await srcFile.length();
      int bytesCopied = 0;

      await for (final chunk in input) {
        output.add(chunk);
        bytesCopied += chunk.length;
        if (totalLength > 0) {
          onProgress(bytesCopied / totalLength);
        }
      }
      await output.close();
      debugPrint('CompressService: Copy done — size: $bytesCopied bytes');
      return File(destPath);
    } else {
      final copiedFile = await srcFile.copy(destPath);
      debugPrint(
          'CompressService: Copy done — size: ${await copiedFile.length()} bytes');
      return copiedFile;
    }
  }

  /// Delete a temporary input copy created by [ensureLocalVideoPath].
  static Future<void> cleanupLocalCopy(File localFile, String originalPath) async {
    if (!Platform.isIOS) return;
    if (localFile.path == originalPath) return; // same file, don't delete
    try {
      if (await localFile.exists()) await localFile.delete();
    } catch (_) {}
  }

  /// Compress image offline with configurable quality (1-100).
  /// [minWidth]/[minHeight]: null = preserve original dimensions.
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
      final targetPath =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: quality,
        minWidth: minWidth ?? 0,
        minHeight: minHeight ?? 0,
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

  /// Compress video offline using hardware acceleration.
  /// Uses light_compressor_v2 for efficient relative-bitrate reduction.
  static Future<File?> compressVideo({
    required String sourcePath,
    required VideoQuality quality,
  }) async {
    File? localCopy;
    try {
      // Ensure we have a stable, app-owned path (critical on iOS)
      localCopy = await ensureLocalVideoPath(sourcePath);

      final String videoName = 'vid_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final inputSize = localCopy.lengthSync();
      debugPrint('CompressService: STARTING light_compressor on ${localCopy.path} (size: $inputSize bytes) with quality: $quality');

      final Result result = await _videoCompressor.compressVideo(
        path: localCopy.path,
        videoQuality: quality,
        isMinBitrateCheckEnabled: false, // Force compression even if source is low-bitrate
        video: Video(videoName: videoName),
        android: AndroidConfig(isSharedStorage: false),
        ios: IOSConfig(saveInGallery: false),
        audio: const AudioConfig(bitrate: 128000, sampleRate: 44100), // Re-encode audio to AAC to prevent iOS native crashes on raw audio (PCM) passthrough
        debugLogging: kDebugMode,
      );


      if (result is OnSuccess) {
        final outputFile = File(result.destinationPath);
        final outputSize = outputFile.lengthSync();
        debugPrint('CompressService: COMPLETED compression. Output: ${result.destinationPath} (size: $outputSize bytes)');
        return outputFile;
      } else if (result is OnFailure) {
        debugPrint('CompressService: FAILED compression: ${result.message}');
        throw Exception(result.message);
      } else if (result is OnCancelled) {
        debugPrint('CompressService: CANCELLED compression');
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('CompressService: compressVideo error: $e');
      rethrow;
    } finally {
      if (localCopy != null) {
        await cleanupLocalCopy(localCopy, sourcePath);
      }
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
    final reduction =
        ((originalSize - compressedSize) / originalSize) * 100;
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

