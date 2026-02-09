import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum FilterType { original, grayscale, blackAndWhite, magicColor }

class ImageProcessor {
  /// Applies a filter to an image file and returns the path to the processed image.
  /// Runs in a separate isolate to prevent UI jank.
  static Future<String> applyFilter(String imagePath, FilterType filter) async {
    if (filter == FilterType.original) {
      return imagePath; // No processing needed
    }

    // Use compute/isolate for heavy lifting
    final resultBytes = await compute(
      _processImageInIsolate,
      _ProcessRequest(imagePath, filter),
    );

    if (resultBytes == null) {
      throw Exception("Failed to process image");
    }

    // Save modified image to a new file (or overwrite temp)
    final originalFile = File(imagePath);
    final dir = originalFile.parent;
    final name = originalFile.uri.pathSegments.last;
    final newPath = '${dir.path}/processed_${filter.name}_$name';

    await File(newPath).writeAsBytes(resultBytes);
    return newPath;
  }

  /// Internal function to run in Isolate
  static Uint8List? _processImageInIsolate(_ProcessRequest request) {
    try {
      final file = File(request.path);
      if (!file.existsSync()) return null;

      final bytes = file.readAsBytesSync();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      // Apply Filters
      switch (request.filter) {
        case FilterType.grayscale:
          image = img.grayscale(image);
          break;
        case FilterType.blackAndWhite:
          image = img.grayscale(image);
          // Apply a threshold to make it straight B&W (binary-like)
          // Simple local implementation of thresholding if not directly available
          image = img.luminanceThreshold(image, threshold: 0.5);
          break;
        case FilterType.magicColor:
          // "Magic Color" usually means high contrast + saturation
          image = img.adjustColor(
            image,
            contrast: 1.2,
            saturation: 1.4,
            brightness: 1.1,
            gamma: 0.9, // Slight gamma correction
          );
          // Sharpen slightly
          image = img.convolution(
            image,
            filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
          );
          break;
        case FilterType.original:
          break;
      }

      // Encode back to JPG
      return img.encodeJpg(image, quality: 85);
    } catch (e) {
      print("Image processing error: $e");
      return null;
    }
  }

  static Future<String> rotate(String imagePath, int angle) async {
    return compute(_rotateTask, _RotateRequest(imagePath, angle));
  }
}

class _RotateRequest {
  final String path;
  final int angle;
  _RotateRequest(this.path, this.angle);
}

Future<String> _rotateTask(_RotateRequest req) async {
  final file = File(req.path);
  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);

  if (image == null) return req.path; // Fail safe

  final rotated = img.copyRotate(image, angle: req.angle);
  final encoded = img.encodeJpg(rotated);

  // Save as new file to avoid cache issues
  // Use a unique name to ensure UI refreshes
  final newName = '${req.path}_rot${DateTime.now().millisecondsSinceEpoch}.jpg';
  final newFile = File(newName);
  await newFile.writeAsBytes(encoded);

  return newFile.path;
}

/// Helper class to pass data to Isolate
class _ProcessRequest {
  final String path;
  final FilterType filter;

  _ProcessRequest(this.path, this.filter);
}
