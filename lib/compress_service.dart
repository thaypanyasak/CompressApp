import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class CompressService {
  static final StreamController<double> _progressController = StreamController<double>.broadcast();

  /// Stream to listen for real-time video compression progress
  static Stream<double> get videoProgressStream {
    VideoCompress.compressProgress$.subscribe((progress) {
      if (!_progressController.isClosed) {
        _progressController.add(progress);
      }
    });
    return _progressController.stream;
  }

  /// Reset VideoCompress internal state. MUST be called before each new
  /// compression to avoid the "won't run after first use" bug caused by
  /// the library's singleton retaining stale session state.
  static Future<void> resetVideoCompress() async {
    try {
      await VideoCompress.cancelCompression();
      await VideoCompress.deleteAllCache();
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
  ///
  /// Returns the local [File] — either the original (if already in sandbox)
  /// or a newly copied one.
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

    // Copy to Documents so iOS does not revoke access during AVAssetExportSession
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
      final targetPath =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$extension';

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

  /// Compress video offline using hardware acceleration.
  ///
  /// On iOS, the source is first copied to the app's Documents directory to
  /// prevent the OS from revoking sandbox access mid-compression.
  ///
  /// Returns the compressed [File], or null if canceled.
  static Future<File?> compressVideo({
    required String sourcePath,
    required VideoQuality quality,
    bool isMinBitrateCheckEnabled = false,
  }) async {
    File? localCopy;
    try {
      // Step 0: Reset VideoCompress singleton state to allow re-use
      await resetVideoCompress();

      // Step 1: Ensure we have a stable, app-owned path (critical on iOS)
      localCopy = await ensureLocalVideoPath(sourcePath);

      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        localCopy.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo != null && mediaInfo.path != null) {
        return File(mediaInfo.path!);
      }
      return null;
    } catch (e) {
      debugPrint('Error compressing video: $e');
      rethrow;
    } finally {
      // Clean up the temporary local copy (not the output file)
      if (localCopy != null) {
        await cleanupLocalCopy(localCopy, sourcePath);
      }
    }
  }


  /// Cancel current active video compression
  static Future<void> cancelVideoCompression() async {
    await VideoCompress.cancelCompression();
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
