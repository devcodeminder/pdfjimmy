import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdfjimmy/features/scanner/camera/scanner_service.dart';
import 'package:pdfjimmy/features/pdf_viewer/utils/pdf_builder.dart';
import 'package:pdfjimmy/features/scanner/enhance/image_processor.dart';
import 'package:pdfjimmy/features/scanner/presentation/scanned_pages_review_screen.dart';
import 'package:pdfjimmy/features/scanner/save_format.dart';

class ScannerController extends GetxController {
  final ScannerService _scannerService = ScannerService();

  // Observable list of scanned image paths
  final RxList<String> scannedPages = <String>[].obs;

  // Loading state
  final RxBool isScanning = false.obs;
  final RxBool isProcessing = false.obs;

  @override
  void onClose() {
    _scannerService.dispose();
    super.onClose();
  }

  // ─── Scan Methods ────────────────────────────────────────────────────────────

  /// Launches the Native ML Kit Document Scanner (Auto scan)
  Future<void> startNativeAutoScan({bool navigateToReview = true}) async {
    try {
      isScanning.value = true;
      final images = await _scannerService.scanDocument();
      if (images.isNotEmpty) {
        scannedPages.addAll(images);
        if (navigateToReview) {
          Get.to(() => const ScannedPagesReviewScreen());
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to scan document: $e');
    } finally {
      isScanning.value = false;
    }
  }

  // ─── Page Management ─────────────────────────────────────────────────────────

  /// Removes a page from the list
  void removePage(int index) {
    if (index >= 0 && index < scannedPages.length) {
      scannedPages.removeAt(index);
    }
  }

  /// Clears all scanned pages
  void clearScan() {
    scannedPages.clear();
  }

  /// Re-orders pages
  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = scannedPages.removeAt(oldIndex);
    scannedPages.insert(newIndex, item);
  }

  /// Updates a page with a newly cropped image
  void updatePageWithCrop(int index, String newPath) {
    if (index < 0 || index >= scannedPages.length) return;
    scannedPages[index] = newPath;
    scannedPages.refresh();
  }

  // ─── Enhancement ─────────────────────────────────────────────────────────────

  /// Applies a filter to a specific page
  Future<void> enhancePage(int index, FilterType filter) async {
    if (index < 0 || index >= scannedPages.length) return;

    try {
      isProcessing.value = true;
      final newPath = await ImageProcessor.applyFilter(
        scannedPages[index],
        filter,
      );
      scannedPages[index] = newPath;
      scannedPages.refresh();
    } catch (e) {
      Get.snackbar('Error', 'Filter failed: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  // ─── Import ───────────────────────────────────────────────────────────────────

  /// Picks an image from the gallery and adds it to the scan session
  Future<void> pickFromGallery() async {
    try {
      isScanning.value = true;
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        scannedPages.add(image.path);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    } finally {
      isScanning.value = false;
    }
  }

  // ─── Export ───────────────────────────────────────────────────────────────────

  /// Saves the current session as a PDF (legacy wrapper)
  Future<String?> saveAsPdf(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return saveAs(fileName: fileName, format: SaveFormat.pdf, saveDirectory: dir.path);
  }

  /// Saves the current session in the chosen format to the chosen directory.
  /// [format]: pdf | jpeg | png
  /// [saveDirectory]: absolute path to directory chosen by user
  Future<String?> saveAs({
    required String fileName,
    required SaveFormat format,
    required String saveDirectory,
  }) async {
    if (scannedPages.isEmpty) return null;

    try {
      isProcessing.value = true;

      final dir = Directory(saveDirectory);
      if (!dir.existsSync()) await dir.create(recursive: true);

      if (format == SaveFormat.pdf) {
        // ── PDF ──────────────────────────────────────────────────────────────
        final safeName = fileName.toLowerCase().endsWith('.pdf')
            ? fileName
            : '$fileName.pdf';
        final outputPath = p.join(saveDirectory, safeName);
        await PdfBuilder.createPdfFromImages(
          imagePaths: scannedPages.toList(),
          outputPath: outputPath,
        );
        Get.snackbar(
          '✅ Saved!',
          'PDF → $outputPath',
          duration: const Duration(seconds: 4),
        );
        return outputPath;
      } else {
        // ── JPEG / PNG ───────────────────────────────────────────────────────
        final ext = format == SaveFormat.jpeg ? 'jpg' : 'png';
        String? lastPath;
        for (int i = 0; i < scannedPages.length; i++) {
          final src = scannedPages[i];
          final destName = scannedPages.length == 1
              ? '$fileName.$ext'
              : '${fileName}_page${i + 1}.$ext';
          final destPath = p.join(saveDirectory, destName);
          if (format == SaveFormat.jpeg) {
            // Compress to JPEG using existing ImageProcessor
            final compressed = await ImageProcessor.compressImage(src, quality: 90);
            await File(compressed).copy(destPath);
          } else {
            // PNG – copy as-is (already PNG from scanner) or convert
            await File(src).copy(destPath);
          }
          lastPath = destPath;
        }
        final label = scannedPages.length == 1 ? '1 image' : '${scannedPages.length} images';
        Get.snackbar(
          '✅ Saved!',
          '$label saved to $saveDirectory',
          duration: const Duration(seconds: 4),
        );
        return lastPath;
      }
    } catch (e) {
      Get.snackbar('Error', 'Save failed: $e');
      return null;
    } finally {
      isProcessing.value = false;
    }
  }

  /// Shares the current session as a PDF
  Future<void> shareCurrentScan() async {
    if (scannedPages.isEmpty) {
      Get.snackbar('Empty', 'No pages to share');
      return;
    }

    try {
      isProcessing.value = true;
      final directory = await getTemporaryDirectory();
      final fileName = 'Share_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputPath = '${directory.path}/$fileName';

      await PdfBuilder.createPdfFromImages(
        imagePaths: scannedPages.toList(),
        outputPath: outputPath,
      );

      await Share.shareXFiles([XFile(outputPath)], text: 'Scanned Document');
    } catch (e) {
      Get.snackbar('Error', 'Failed to share: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  // ─── Smart Title ─────────────────────────────────────────────────────────────

  /// Generates a simple smart title from the first scanned page filename
  Future<String> generateSmartTitle() async {
    if (scannedPages.isEmpty) {
      return 'Scan_${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'Scan_${DateTime.now().millisecondsSinceEpoch}';
  }
}
