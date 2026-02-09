import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Improved background removal with optimal balance of speed and quality.
/// Features: Smart object detection, edge preservation, and smooth alpha matting.
class AIBackgroundRemover {
  static Future<Uint8List> removeBackground(Uint8List imageData) async {
    return await compute(_processImproved, imageData);
  }

  static Uint8List _processImproved(Uint8List imageData) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) throw Exception('Failed to decode image');

      // Adaptive downsampling for speed
      final scale = _getOptimalScale(image.width, image.height);
      final working = scale < 1.0
          ? img.copyResize(image, width: (image.width * scale).toInt())
          : image;

      // 1. Robust background analysis
      final bgModel = _analyzeBackground(working);

      // 2. Create initial segmentation
      final segmentation = _createSegmentation(working, bgModel);

      // 3. Detect and preserve edges
      final edges = _detectEdges(working);

      // 4. Find main object
      final objectMask = _findMainObject(segmentation, edges);

      // 5. Refine boundaries
      final refined = _refineBoundaries(objectMask, edges, working);

      // 6. Upscale if needed
      final fullMask = scale < 1.0
          ? _upscaleMask(refined, image.width, image.height)
          : refined;

      // 7. Apply with color correction
      final output = _applyMask(image, fullMask, bgModel);

      return Uint8List.fromList(img.encodePng(output));
    } catch (e) {
      throw Exception('Background removal failed: $e');
    }
  }

  static double _getOptimalScale(int w, int h) {
    const target = 600;
    final maxDim = math.max(w, h);
    return maxDim > target ? target / maxDim : 1.0;
  }

  static _BgModel _analyzeBackground(img.Image image) {
    final samples = <_Sample>[];
    final step = 3;

    // Multi-depth border sampling
    for (final depth in [0.04, 0.08]) {
      final bx = (image.width * depth).ceil();
      final by = (image.height * depth).ceil();

      for (int y = 0; y < by; y += step) {
        for (int x = 0; x < image.width; x += step) {
          samples.add(_getSample(image, x, y));
          samples.add(_getSample(image, x, image.height - 1 - y));
        }
      }

      for (int x = 0; x < bx; x += step) {
        for (int y = by; y < image.height - by; y += step) {
          samples.add(_getSample(image, x, y));
          samples.add(_getSample(image, image.width - 1 - x, y));
        }
      }
    }

    // Robust statistics
    double sumR = 0, sumG = 0, sumB = 0;
    for (final s in samples) {
      sumR += s.r;
      sumG += s.g;
      sumB += s.b;
    }
    final count = samples.length;
    final meanR = sumR / count, meanG = sumG / count, meanB = sumB / count;

    double sumSqR = 0, sumSqG = 0, sumSqB = 0;
    for (final s in samples) {
      sumSqR += (s.r - meanR) * (s.r - meanR);
      sumSqG += (s.g - meanG) * (s.g - meanG);
      sumSqB += (s.b - meanB) * (s.b - meanB);
    }

    final stdR = math.sqrt(sumSqR / count);
    final stdG = math.sqrt(sumSqG / count);
    final stdB = math.sqrt(sumSqB / count);

    return _BgModel(
      meanR,
      meanG,
      meanB,
      math.max(stdR, 8.0),
      math.max(stdG, 8.0),
      math.max(stdB, 8.0),
    );
  }

  static List<List<double>> _createSegmentation(img.Image image, _BgModel bg) {
    final w = image.width, h = image.height;
    final seg = List.generate(h, (_) => List.filled(w, 0.0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final dr = (p.r - bg.meanR) / bg.stdR;
        final dg = (p.g - bg.meanG) / bg.stdG;
        final db = (p.b - bg.meanB) / bg.stdB;
        final dist = math.sqrt(dr * dr + dg * dg + db * db);

        // Foreground probability
        seg[y][x] = (1.0 - math.exp(-dist / 2.5)).clamp(0.0, 1.0);
      }
    }

    return seg;
  }

  static List<List<double>> _detectEdges(img.Image image) {
    final w = image.width, h = image.height;
    final edges = List.generate(h, (_) => List.filled(w, 0.0));

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double gx = 0, gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final p = image.getPixel(x + kx, y + ky);
            final intensity = (p.r + p.g + p.b) / 3;
            gx +=
                intensity *
                [
                  [-1, 0, 1],
                  [-2, 0, 2],
                  [-1, 0, 1],
                ][ky + 1][kx + 1];
            gy +=
                intensity *
                [
                  [-1, -2, -1],
                  [0, 0, 0],
                  [1, 2, 1],
                ][ky + 1][kx + 1];
          }
        }

        edges[y][x] = (math.sqrt(gx * gx + gy * gy) / 255.0).clamp(0.0, 1.0);
      }
    }

    return edges;
  }

  static List<List<double>> _findMainObject(
    List<List<double>> seg,
    List<List<double>> edges,
  ) {
    final h = seg.length, w = seg[0].length;
    final binary = List.generate(h, (_) => List.filled(w, false));

    // Threshold
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        binary[y][x] = seg[y][x] > 0.35;
      }
    }

    // Connected components
    final labels = List.generate(h, (_) => List.filled(w, -1));
    final sizes = <int, int>{};
    int label = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (binary[y][x] && labels[y][x] == -1) {
          sizes[label] = _floodFill(binary, labels, x, y, label, w, h);
          label++;
        }
      }
    }

    // Find largest
    int maxLabel = -1, maxSize = 0;
    sizes.forEach((l, s) {
      if (s > maxSize) {
        maxSize = s;
        maxLabel = l;
      }
    });

    // Create object mask
    final mask = List.generate(h, (_) => List.filled(w, 0.0));
    if (maxLabel != -1) {
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (labels[y][x] == maxLabel) {
            mask[y][x] = seg[y][x];
          }
        }
      }
    }

    return mask;
  }

  static int _floodFill(
    List<List<bool>> binary,
    List<List<int>> labels,
    int sx,
    int sy,
    int label,
    int w,
    int h,
  ) {
    final stack = <_Pt>[_Pt(sx, sy)];
    int size = 0;

    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      if (p.x < 0 || p.x >= w || p.y < 0 || p.y >= h) continue;
      if (!binary[p.y][p.x] || labels[p.y][p.x] != -1) continue;

      labels[p.y][p.x] = label;
      size++;

      stack.add(_Pt(p.x + 1, p.y));
      stack.add(_Pt(p.x - 1, p.y));
      stack.add(_Pt(p.x, p.y + 1));
      stack.add(_Pt(p.x, p.y - 1));
    }

    return size;
  }

  static List<List<double>> _refineBoundaries(
    List<List<double>> mask,
    List<List<double>> edges,
    img.Image image,
  ) {
    final h = mask.length, w = mask[0].length;
    final refined = List.generate(h, (_) => List.filled(w, 0.0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sum = 0;
        int count = 0;

        // 5x5 neighborhood
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            final ny = (y + dy).clamp(0, h - 1);
            final nx = (x + dx).clamp(0, w - 1);
            final weight = 1.0 / (1.0 + dx * dx + dy * dy);
            sum += mask[ny][nx] * weight;
            count++;
          }
        }

        var alpha = sum / count;

        // Edge boost
        if (edges[y][x] > 0.3 && alpha > 0.2) {
          alpha = math.min(alpha + 0.2, 1.0);
        }

        refined[y][x] = alpha;
      }
    }

    return refined;
  }

  static List<List<double>> _upscaleMask(
    List<List<double>> mask,
    int targetW,
    int targetH,
  ) {
    final srcH = mask.length, srcW = mask[0].length;
    final result = List.generate(targetH, (_) => List.filled(targetW, 0.0));

    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        final srcX = (x * srcW / targetW).floor().clamp(0, srcW - 1);
        final srcY = (y * srcH / targetH).floor().clamp(0, srcH - 1);
        result[y][x] = mask[srcY][srcX];
      }
    }

    return result;
  }

  static img.Image _applyMask(
    img.Image image,
    List<List<double>> mask,
    _BgModel bg,
  ) {
    final output = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final alpha = mask[y][x];

        if (alpha < 0.01) {
          output.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        } else {
          final p = image.getPixel(x, y);
          int r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

          // Color decontamination
          if (alpha > 0.01 && alpha < 0.98) {
            r = ((r - bg.meanR * (1 - alpha)) / alpha).clamp(0, 255).toInt();
            g = ((g - bg.meanG * (1 - alpha)) / alpha).clamp(0, 255).toInt();
            b = ((b - bg.meanB * (1 - alpha)) / alpha).clamp(0, 255).toInt();
          }

          output.setPixel(x, y, img.ColorRgba8(r, g, b, (alpha * 255).toInt()));
        }
      }
    }

    return output;
  }

  static _Sample _getSample(img.Image image, int x, int y) {
    final p = image.getPixel(x, y);
    return _Sample(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
  }
}

class _BgModel {
  final double meanR, meanG, meanB, stdR, stdG, stdB;
  _BgModel(this.meanR, this.meanG, this.meanB, this.stdR, this.stdG, this.stdB);
}

class _Sample {
  final double r, g, b;
  _Sample(this.r, this.g, this.b);
}

class _Pt {
  final int x, y;
  _Pt(this.x, this.y);
}
