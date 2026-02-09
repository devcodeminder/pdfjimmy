import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf_lib;
import 'package:path_provider/path_provider.dart';

/// Service for sharing PDFs and specific pages
class PdfShareService {
  static final PdfShareService instance = PdfShareService._init();

  PdfShareService._init();

  /// Share entire PDF
  Future<void> sharePdf(String filePath, {String? message}) async {
    try {
      await Share.shareXFiles([
        XFile(filePath),
      ], text: message ?? 'Sharing PDF document');
    } catch (e) {
      print('Error sharing PDF: $e');
      rethrow;
    }
  }

  /// Share specific pages as a new PDF
  Future<void> sharePages(
    String filePath,
    List<int> pageNumbers, {
    String? message,
  }) async {
    try {
      // Create PDF with selected pages
      final newPdfPath = await _createPdfFromPages(filePath, pageNumbers);

      // Share the new PDF
      await Share.shareXFiles([
        XFile(newPdfPath),
      ], text: message ?? 'Sharing selected pages');

      // Clean up temporary file after a delay
      Future.delayed(const Duration(seconds: 5), () {
        try {
          File(newPdfPath).deleteSync();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      });
    } catch (e) {
      print('Error sharing pages: $e');
      rethrow;
    }
  }

  /// Share page range
  Future<void> sharePageRange(
    String filePath,
    int startPage,
    int endPage, {
    String? message,
  }) async {
    final pageNumbers = List.generate(
      endPage - startPage + 1,
      (index) => startPage + index,
    );
    await sharePages(filePath, pageNumbers, message: message);
  }

  /// Share current page
  Future<void> shareCurrentPage(
    String filePath,
    int pageNumber, {
    String? message,
  }) async {
    await sharePages(filePath, [pageNumber], message: message);
  }

  /// Share as images (convert pages to images)
  /// Note: This feature requires additional image rendering library
  Future<void> sharePagesAsImages(
    String filePath,
    List<int> pageNumbers, {
    String? message,
  }) async {
    // Note: Syncfusion PDF doesn't support direct page-to-image conversion
    // For this feature, you would need to use a package like pdf_render
    // For now, we'll share the pages as a PDF instead
    await sharePages(filePath, pageNumbers, message: message);
  }

  /// Share with specific apps
  Future<void> shareWithOptions(
    String filePath, {
    String? subject,
    String? message,
    Rect? sharePositionOrigin,
  }) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: message,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      print('Error sharing with options: $e');
      rethrow;
    }
  }

  /// Get shareable link (if cloud sync is enabled)
  Future<String?> getShareableLink(String filePath) async {
    // This would integrate with cloud sync service
    // For now, return null
    return null;
  }

  // ==================== Private Helper Methods ====================

  /// Create a new PDF from selected pages
  Future<String> _createPdfFromPages(
    String filePath,
    List<int> pageNumbers,
  ) async {
    try {
      // Load original PDF
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final document = pdf_lib.PdfDocument(inputBytes: bytes);

      // Create new PDF with selected pages
      final newDocument = pdf_lib.PdfDocument();

      for (final pageNum in pageNumbers) {
        if (pageNum >= 0 && pageNum < document.pages.count) {
          // Import page to new document
          final template = document.pages[pageNum].createTemplate();
          final newPage = newDocument.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
      }

      // Save new PDF
      final newBytes = await newDocument.save();
      document.dispose();
      newDocument.dispose();

      // Write to temporary file
      final directory = await getTemporaryDirectory();
      final fileName = _getFileName(filePath);
      final nameWithoutExt = fileName.replaceAll('.pdf', '');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath =
          '${directory.path}/${nameWithoutExt}_pages_$timestamp.pdf';
      final newFile = File(newPath);
      await newFile.writeAsBytes(newBytes);

      return newPath;
    } catch (e) {
      print('Error creating PDF from pages: $e');
      rethrow;
    }
  }

  String _getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }
}
