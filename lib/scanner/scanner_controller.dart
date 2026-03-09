import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfjimmy/scanner/camera/scanner_service.dart';
import 'package:pdfjimmy/pdf/pdf_builder.dart';
import 'package:pdfjimmy/scanner/enhance/image_processor.dart';
import 'package:pdfjimmy/scanner/camera/custom_camera_screen.dart';

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

  /// Launches the Custom Camera Screen
  Future<void> startScan({bool navigateToReview = true}) async {
    Get.to(() => const CustomCameraScreen());
  }

  /// Convenience wrapper kept for home_screen compatibility
  Future<void> scanWithFastPackage() async => startScan();

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

  /// Saves the current session as a PDF
  Future<String?> saveAsPdf(String fileName) async {
    if (scannedPages.isEmpty) return null;

    try {
      isProcessing.value = true;
      final directory = await getApplicationDocumentsDirectory();
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName += '.pdf';
      }
      final outputPath = '${directory.path}/$fileName';

      await PdfBuilder.createPdfFromImages(
        imagePaths: scannedPages.toList(),
        outputPath: outputPath,
      );

      Get.snackbar('Success', 'PDF saved to $outputPath');
      return outputPath;
    } catch (e) {
      Get.snackbar('Error', 'Failed to generate PDF: $e');
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
