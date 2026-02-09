import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf_lib;
import 'package:path_provider/path_provider.dart';

/// Service for PDF compression and optimization
class PdfCompressionService {
  static final PdfCompressionService instance = PdfCompressionService._init();

  PdfCompressionService._init();

  /// Compression quality levels
  static const int qualityLow = 30;
  static const int qualityMedium = 60;
  static const int qualityHigh = 80;

  /// Compress a PDF file
  /// Returns the path to the compressed file
  Future<String> compressPdf(
    String filePath, {
    int quality = qualityMedium,
    bool removeMetadata = true,
    bool optimizeImages = true,
    bool removeUnusedObjects = true,
  }) async {
    try {
      // Load the PDF document
      final File file = File(filePath);
      final Uint8List bytes = await file.readAsBytes();
      final pdf_lib.PdfDocument document = pdf_lib.PdfDocument(
        inputBytes: bytes,
      );

      // Apply compression settings
      if (optimizeImages) {
        await _optimizeImages(document, quality);
      }

      if (removeMetadata) {
        _removeMetadata(document);
      }

      if (removeUnusedObjects) {
        // Syncfusion automatically removes unused objects during save
      }

      // Set compression level
      document.compressionLevel = _getCompressionLevel(quality);

      // Save the compressed document
      final List<int> compressedBytes = await document.save();
      document.dispose();

      // Create compressed file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getCompressedFileName(filePath);
      final compressedPath = '${directory.path}/$fileName';
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedPath;
    } catch (e) {
      print('Error compressing PDF: $e');
      rethrow;
    }
  }

  /// Optimize PDF for viewing (reduce file size while maintaining quality)
  Future<String> optimizeForViewing(String filePath) async {
    return await compressPdf(
      filePath,
      quality: qualityHigh,
      removeMetadata: false,
      optimizeImages: true,
      removeUnusedObjects: true,
    );
  }

  /// Optimize PDF for sharing (maximum compression)
  Future<String> optimizeForSharing(String filePath) async {
    return await compressPdf(
      filePath,
      quality: qualityLow,
      removeMetadata: true,
      optimizeImages: true,
      removeUnusedObjects: true,
    );
  }

  /// Get file size in MB
  Future<double> getFileSizeMB(String filePath) async {
    final file = File(filePath);
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Calculate compression ratio
  Future<Map<String, dynamic>> getCompressionStats(
    String originalPath,
    String compressedPath,
  ) async {
    final originalSize = await getFileSizeMB(originalPath);
    final compressedSize = await getFileSizeMB(compressedPath);
    final savedSize = originalSize - compressedSize;
    final compressionRatio = ((savedSize / originalSize) * 100);

    return {
      'originalSizeMB': originalSize,
      'compressedSizeMB': compressedSize,
      'savedSizeMB': savedSize,
      'compressionRatio': compressionRatio,
    };
  }

  // ==================== Private Helper Methods ====================

  /// Optimize images in the PDF
  Future<void> _optimizeImages(
    pdf_lib.PdfDocument document,
    int quality,
  ) async {
    try {
      // Note: Syncfusion PDF doesn't provide direct image extraction/replacement
      // Image optimization happens during save with compression level
      // This is handled by the compressionLevel setting
    } catch (e) {
      print('Error optimizing images: $e');
    }
  }

  /// Remove metadata from PDF
  void _removeMetadata(pdf_lib.PdfDocument document) {
    try {
      // Clear document information
      document.documentInformation.title = '';
      document.documentInformation.author = '';
      document.documentInformation.subject = '';
      document.documentInformation.keywords = '';
      document.documentInformation.creator = '';
      document.documentInformation.producer = '';
    } catch (e) {
      print('Error removing metadata: $e');
    }
  }

  /// Get compression level based on quality
  pdf_lib.PdfCompressionLevel _getCompressionLevel(int quality) {
    if (quality <= 40) {
      return pdf_lib.PdfCompressionLevel.best;
    } else if (quality <= 70) {
      return pdf_lib.PdfCompressionLevel.normal;
    } else {
      return pdf_lib.PdfCompressionLevel.none;
    }
  }

  /// Generate compressed file name
  String _getCompressedFileName(String originalPath) {
    final file = File(originalPath);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.replaceAll('.pdf', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${nameWithoutExt}_compressed_$timestamp.pdf';
  }

  /// Estimate compression potential
  Future<Map<String, dynamic>> estimateCompression(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = pdf_lib.PdfDocument(inputBytes: bytes);

    final pageCount = document.pages.count;
    final hasImages = _hasImages(document);
    final hasMetadata = _hasMetadata(document);

    document.dispose();

    // Estimate potential compression
    double estimatedReduction = 0.0;
    if (hasImages) estimatedReduction += 30.0;
    if (hasMetadata) estimatedReduction += 5.0;
    if (pageCount > 50) estimatedReduction += 10.0;

    return {
      'pageCount': pageCount,
      'hasImages': hasImages,
      'hasMetadata': hasMetadata,
      'estimatedReduction': estimatedReduction.clamp(0.0, 70.0),
    };
  }

  /// Check if document has images
  bool _hasImages(pdf_lib.PdfDocument document) {
    try {
      // Note: Syncfusion PDF doesn't provide direct image info access
      // Assume documents may have images for estimation purposes
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if document has metadata
  bool _hasMetadata(pdf_lib.PdfDocument document) {
    try {
      final info = document.documentInformation;
      return (info.title.isNotEmpty) ||
          (info.author.isNotEmpty) ||
          (info.subject.isNotEmpty);
    } catch (e) {
      return false;
    }
  }
}
