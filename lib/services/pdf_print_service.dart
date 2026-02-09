import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

/// Service for PDF printing functionality
class PdfPrintService {
  static final PdfPrintService instance = PdfPrintService._init();

  PdfPrintService._init();

  /// Print entire PDF
  Future<void> printPdf(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      await Printing.layoutPdf(
        onLayout: (pw_pdf.PdfPageFormat format) async => bytes,
        name: _getFileName(filePath),
      );
    } catch (e) {
      print('Error printing PDF: $e');
      rethrow;
    }
  }

  /// Print specific pages
  Future<void> printPages(String filePath, List<int> pageNumbers) async {
    try {
      // Load original PDF
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final document = sf_pdf.PdfDocument(inputBytes: bytes);

      // Create new PDF with selected pages
      final newDocument = sf_pdf.PdfDocument();

      for (final pageNum in pageNumbers) {
        if (pageNum >= 0 && pageNum < document.pages.count) {
          // Import page
          final template = document.pages[pageNum].createTemplate();
          final newPage = newDocument.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
      }

      // Save and print
      final newBytes = Uint8List.fromList(await newDocument.save());
      document.dispose();
      newDocument.dispose();

      await Printing.layoutPdf(
        onLayout: (pw_pdf.PdfPageFormat format) async => newBytes,
        name: '${_getFileName(filePath)}_pages_${pageNumbers.join("_")}',
      );
    } catch (e) {
      print('Error printing pages: $e');
      rethrow;
    }
  }

  /// Print page range
  Future<void> printPageRange(
    String filePath,
    int startPage,
    int endPage,
  ) async {
    final pageNumbers = List.generate(
      endPage - startPage + 1,
      (index) => startPage + index,
    );
    await printPages(filePath, pageNumbers);
  }

  /// Print current page
  Future<void> printCurrentPage(String filePath, int pageNumber) async {
    await printPages(filePath, [pageNumber]);
  }

  /// Share PDF for printing
  Future<void> sharePdf(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      await Printing.sharePdf(bytes: bytes, filename: _getFileName(filePath));
    } catch (e) {
      print('Error sharing PDF: $e');
      rethrow;
    }
  }

  /// Get available printers
  Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      print('Error getting printers: $e');
      return [];
    }
  }

  /// Print with specific printer
  Future<void> printWithPrinter(String filePath, Printer printer) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (pw_pdf.PdfPageFormat format) async => bytes,
        name: _getFileName(filePath),
      );
    } catch (e) {
      print('Error printing with specific printer: $e');
      rethrow;
    }
  }

  /// Show print preview dialog
  Future<void> showPrintPreview(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      await Printing.layoutPdf(
        onLayout: (pw_pdf.PdfPageFormat format) async => bytes,
        name: _getFileName(filePath),
      );
    } catch (e) {
      print('Error showing print preview: $e');
      rethrow;
    }
  }

  /// Check if printing is available
  Future<bool> isPrintingAvailable() async {
    try {
      await Printing.info();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== Private Helper Methods ====================

  String _getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }
}
