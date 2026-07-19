import 'dart:io';
import 'package:image/image.dart' as img;

class ImageEnhanceParams {
  final String sourcePath;
  final String outputPath;
  final double upscaleFactor;
  final double sharpnessLevel;
  final bool enableHdr;
  final bool enableDenoise;

  ImageEnhanceParams({
    required this.sourcePath,
    required this.outputPath,
    required this.upscaleFactor,
    required this.sharpnessLevel,
    this.enableHdr = true,
    this.enableDenoise = true,
  });
}

class ImageEnhanceResult {
  final String path;
  final int originalWidth;
  final int originalHeight;
  final int enhancedWidth;
  final int enhancedHeight;
  final int fileSize;

  ImageEnhanceResult({
    required this.path,
    required this.originalWidth,
    required this.originalHeight,
    required this.enhancedWidth,
    required this.enhancedHeight,
    required this.fileSize,
  });
}

Future<ImageEnhanceResult> enhanceImageWork(ImageEnhanceParams params) async {
  final bytes = await File(params.sourcePath).readAsBytes();
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('ไม่สามารถถอดรหัสรูปภาพได้');
  }

  final origWidth = image.width;
  final origHeight = image.height;

  // 1. Denoise Pre-pass (if enabled) to eliminate film grain noise before sharpening
  if (params.enableDenoise) {
    image = img.gaussianBlur(image, radius: 1);
  }

  // 2. Bicubic High-Quality Upscaling (Up to 4K max 3840px)
  if (params.upscaleFactor > 1.0) {
    var targetWidth = (origWidth * params.upscaleFactor).round();
    var targetHeight = (origHeight * params.upscaleFactor).round();

    // Prevent OOM by capping maximum dimension at 3840 (4K)
    if (targetWidth > 3840 || targetHeight > 3840) {
      if (targetWidth > targetHeight) {
        targetHeight = (targetHeight * (3840 / targetWidth)).round();
        targetWidth = 3840;
      } else {
        targetWidth = (targetWidth * (3840 / targetHeight)).round();
        targetHeight = 3840;
      }
    }

    image = img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  // 3. Multi-Pass Adaptive Convolution Sharpening
  List<double> kernel;
  if (params.sharpnessLevel == 1.0) {
    kernel = [
       0.0, -0.4,  0.0,
      -0.4,  2.6, -0.4,
       0.0, -0.4,  0.0,
    ];
  } else if (params.sharpnessLevel == 2.0) {
    kernel = [
       0.0, -0.8,  0.0,
      -0.8,  4.2, -0.8,
       0.0, -0.8,  0.0,
    ];
  } else if (params.sharpnessLevel == 3.0) {
    kernel = [
      -1.0, -1.0, -1.0,
      -1.0,  9.0, -1.0,
      -1.0, -1.0, -1.0,
    ];
  } else {
    // Ultra 4K Sharp Kernel
    kernel = [
      -1.5, -1.5, -1.5,
      -1.5, 13.0, -1.5,
      -1.5, -1.5, -1.5,
    ];
  }

  image = img.convolution(image, filter: kernel);

  // 4. HDR Micro-Contrast & Vibrance Tuning (if enabled)
  if (params.enableHdr) {
    image = img.adjustColor(
      image,
      contrast: 1.08,
      saturation: 1.05,
    );
  }

  // 5. Save as Ultra High-Quality JPEG (98% purity)
  final enhancedBytes = img.encodeJpg(image, quality: 98);
  final enhancedFile = File(params.outputPath);
  await enhancedFile.writeAsBytes(enhancedBytes);

  return ImageEnhanceResult(
    path: enhancedFile.path,
    originalWidth: origWidth,
    originalHeight: origHeight,
    enhancedWidth: image.width,
    enhancedHeight: image.height,
    fileSize: enhancedBytes.length,
  );
}
