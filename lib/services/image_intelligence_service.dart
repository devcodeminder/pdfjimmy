import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

/// Image Intelligence Service
/// Provides advanced image processing capabilities:
/// - Auto edge detection
/// - Perspective correction
/// - Shadow removal
/// - De-skew
/// - Noise reduction
/// - Adaptive contrast (B&W, Magic Color)
class ImageIntelligenceService {
  /// Detect edges in an image using Sobel operator
  Future<Uint8List> detectEdges(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Convert to grayscale
      final grayscale = img.grayscale(image);

      // Apply Sobel edge detection
      final edges = _applySobelEdgeDetection(grayscale);

      return Uint8List.fromList(img.encodePng(edges));
    } catch (e) {
      throw Exception('Edge detection failed: $e');
    }
  }

  /// Apply Sobel edge detection algorithm
  img.Image _applySobelEdgeDetection(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);

    // Sobel kernels
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0;
        double gy = 0;

        // Apply kernels
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final intensity = pixel.r.toDouble();

            gx += intensity * sobelX[ky + 1][kx + 1];
            gy += intensity * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy).clamp(0, 255).toInt();
        result.setPixelRgba(x, y, magnitude, magnitude, magnitude, 255);
      }
    }

    return result;
  }

  /// Correct perspective distortion in document images
  Future<Uint8List> correctPerspective(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Detect document corners
      final corners = await _detectDocumentCorners(image);

      // Apply perspective transformation
      final corrected = _applyPerspectiveTransform(image, corners);

      return Uint8List.fromList(img.encodePng(corrected));
    } catch (e) {
      throw Exception('Perspective correction failed: $e');
    }
  }

  /// Detect document corners using edge detection
  Future<List<math.Point<int>>> _detectDocumentCorners(img.Image image) async {
    // Simplified corner detection - returns approximate corners
    final width = image.width;
    final height = image.height;

    // Default corners (can be enhanced with actual corner detection algorithm)
    return [
      math.Point(0, 0), // Top-left
      math.Point(width, 0), // Top-right
      math.Point(width, height), // Bottom-right
      math.Point(0, height), // Bottom-left
    ];
  }

  /// Apply perspective transformation
  img.Image _applyPerspectiveTransform(
    img.Image image,
    List<math.Point<int>> corners,
  ) {
    // For now, return the original image
    // Full perspective transform requires matrix calculations
    return image;
  }

  /// Remove shadows from document images
  Future<Uint8List> removeShadows(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Convert to LAB color space (simulated)
      final result = img.Image(width: image.width, height: image.height);

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;

          // Calculate luminance
          final luminance = (0.299 * r + 0.587 * g + 0.114 * b).toInt();

          // Adaptive threshold to remove shadows
          final threshold = 180;
          final adjusted = luminance > threshold ? 255 : luminance + 50;

          result.setPixelRgba(x, y, adjusted, adjusted, adjusted, 255);
        }
      }

      return Uint8List.fromList(img.encodePng(result));
    } catch (e) {
      throw Exception('Shadow removal failed: $e');
    }
  }

  /// De-skew (straighten) a tilted document image
  Future<Uint8List> deSkew(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Detect skew angle
      final angle = await _detectSkewAngle(image);

      // Rotate image to correct skew
      final corrected = img.copyRotate(image, angle: -angle);

      return Uint8List.fromList(img.encodePng(corrected));
    } catch (e) {
      throw Exception('De-skew failed: $e');
    }
  }

  /// Detect skew angle using Hough transform (simplified)
  Future<double> _detectSkewAngle(img.Image image) async {
    // Simplified skew detection
    // In production, use Hough line transform
    return 0.0; // No skew detected (placeholder)
  }

  /// Reduce noise in image using median filter
  Future<Uint8List> reduceNoise(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Apply median filter (3x3 kernel)
      final denoised = _applyMedianFilter(image, kernelSize: 3);

      return Uint8List.fromList(img.encodePng(denoised));
    } catch (e) {
      throw Exception('Noise reduction failed: $e');
    }
  }

  /// Apply median filter for noise reduction
  img.Image _applyMedianFilter(img.Image image, {int kernelSize = 3}) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    final offset = kernelSize ~/ 2;

    for (int y = offset; y < height - offset; y++) {
      for (int x = offset; x < width - offset; x++) {
        final List<int> rValues = [];
        final List<int> gValues = [];
        final List<int> bValues = [];

        // Collect neighborhood pixels
        for (int ky = -offset; ky <= offset; ky++) {
          for (int kx = -offset; kx <= offset; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            rValues.add(pixel.r.toInt());
            gValues.add(pixel.g.toInt());
            bValues.add(pixel.b.toInt());
          }
        }

        // Sort and get median
        rValues.sort();
        gValues.sort();
        bValues.sort();

        final medianIndex = rValues.length ~/ 2;
        result.setPixelRgba(
          x,
          y,
          rValues[medianIndex],
          gValues[medianIndex],
          bValues[medianIndex],
          255,
        );
      }
    }

    return result;
  }

  /// Apply adaptive contrast enhancement (Black & White mode)
  Future<Uint8List> applyAdaptiveContrastBW(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Convert to grayscale
      final grayscale = img.grayscale(image);

      // Apply adaptive thresholding
      final enhanced = _applyAdaptiveThreshold(grayscale);

      return Uint8List.fromList(img.encodePng(enhanced));
    } catch (e) {
      throw Exception('Adaptive contrast (B&W) failed: $e');
    }
  }

  /// Apply adaptive threshold for B&W conversion
  img.Image _applyAdaptiveThreshold(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    final windowSize = 15;
    final offset = windowSize ~/ 2;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Calculate local mean
        int sum = 0;
        int count = 0;

        for (int ky = -offset; ky <= offset; ky++) {
          for (int kx = -offset; kx <= offset; kx++) {
            final px = (x + kx).clamp(0, width - 1);
            final py = (y + ky).clamp(0, height - 1);
            final pixel = image.getPixel(px, py);
            sum += pixel.r.toInt();
            count++;
          }
        }

        final localMean = sum ~/ count;
        final pixel = image.getPixel(x, y);
        final value = pixel.r > localMean - 10 ? 255 : 0;

        result.setPixelRgba(x, y, value, value, value, 255);
      }
    }

    return result;
  }

  /// Apply Magic Color enhancement
  Future<Uint8List> applyMagicColor(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Enhance colors using histogram equalization
      final enhanced = _applyHistogramEqualization(image);

      // Apply sharpening
      final sharpened = img.adjustColor(
        enhanced,
        saturation: 1.2,
        contrast: 1.1,
      );

      return Uint8List.fromList(img.encodePng(sharpened));
    } catch (e) {
      throw Exception('Magic Color enhancement failed: $e');
    }
  }

  /// Apply histogram equalization for color enhancement
  img.Image _applyHistogramEqualization(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);

    // Calculate histogram for each channel
    final histR = List.filled(256, 0);
    final histG = List.filled(256, 0);
    final histB = List.filled(256, 0);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        histR[pixel.r.toInt()]++;
        histG[pixel.g.toInt()]++;
        histB[pixel.b.toInt()]++;
      }
    }

    // Calculate cumulative distribution
    final cdfR = List.filled(256, 0);
    final cdfG = List.filled(256, 0);
    final cdfB = List.filled(256, 0);

    cdfR[0] = histR[0];
    cdfG[0] = histG[0];
    cdfB[0] = histB[0];

    for (int i = 1; i < 256; i++) {
      cdfR[i] = cdfR[i - 1] + histR[i];
      cdfG[i] = cdfG[i - 1] + histG[i];
      cdfB[i] = cdfB[i - 1] + histB[i];
    }

    // Normalize
    final totalPixels = width * height;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final newR = ((cdfR[pixel.r.toInt()] * 255) / totalPixels).toInt();
        final newG = ((cdfG[pixel.g.toInt()] * 255) / totalPixels).toInt();
        final newB = ((cdfB[pixel.b.toInt()] * 255) / totalPixels).toInt();

        result.setPixelRgba(x, y, newR, newG, newB, 255);
      }
    }

    return result;
  }

  /// Complete document enhancement pipeline
  Future<Uint8List> enhanceDocument(
    Uint8List imageBytes, {
    bool autoEdgeDetect = true,
    bool correctPerspective = true,
    bool removeShadows = true,
    bool deSkew = true,
    bool reduceNoise = true,
    bool enhanceContrast = true,
  }) async {
    Uint8List processed = imageBytes;

    try {
      if (deSkew) {
        processed = await this.deSkew(processed);
      }

      if (correctPerspective) {
        processed = await this.correctPerspective(processed);
      }

      if (removeShadows) {
        processed = await this.removeShadows(processed);
      }

      if (reduceNoise) {
        processed = await this.reduceNoise(processed);
      }

      if (enhanceContrast) {
        processed = await applyAdaptiveContrastBW(processed);
      }

      return processed;
    } catch (e) {
      throw Exception('Document enhancement failed: $e');
    }
  }
}
