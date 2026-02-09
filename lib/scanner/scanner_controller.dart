import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart'; // Add camera import
import 'package:flutter/services.dart'; // For Clipboard
import 'package:pdfjimmy/scanner/camera/scanner_service.dart';
import 'package:pdfjimmy/pdf/pdf_builder.dart';
import 'package:pdfjimmy/ai/ocr/ocr_service.dart';
import 'package:pdfjimmy/ai/insights/ai_insights_service.dart';
import 'package:pdfjimmy/scanner/enhance/image_processor.dart';
import 'package:flutter/material.dart'; // For BuildContext in captureImage
import 'package:gap/gap.dart';
import 'package:pdfjimmy/scanner/presentation/handwriting_result_screen.dart';
import 'package:pdfjimmy/scanner/presentation/translation_result_screen.dart';

enum ScannerMode { scan, translate }

class ScannerController extends GetxController with WidgetsBindingObserver {
  final ScannerService _scannerService = ScannerService();
  final OcrService _ocrService = OcrService();
  final AiInsightsService _aiInsightsService = AiInsightsService();

  // Observable list of scanned image paths
  final RxList<String> scannedPages = <String>[].obs;

  // Loading state
  final RxBool isScanning = false.obs;
  final RxBool isProcessing = false.obs;

  // Modes & Translation
  final Rx<ScannerMode> currentMode = ScannerMode.scan.obs;
  final RxString sourceLanguage = "Detect language".obs;
  final RxString targetLanguage = "Hindi".obs;
  final RxString targetLanguageCode = "hi".obs;

  final Map<String, String> supportedLanguages = {
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'ar': 'Arabic',
    'pt': 'Portuguese',
    'en': 'English',
    'bn': 'Bengali',
    'pa': 'Punjabi',
  };

  // Camera Logic
  CameraController? cameraController;
  RxBool isCameraInitialized = false.obs;
  RxBool isFlashOn = false.obs;
  RxBool isAutoMode = true.obs;
  RxBool isBatchMode = false.obs;
  Rx<FilterType> selectedLiveFilter = FilterType.original.obs;
  RxBool isAutoCropEnabled = true.obs;
  Rx<DocCategory> detectedCategory = DocCategory.unknown.obs;
  RxList<AiEntity> detectedEntities = <AiEntity>[].obs;

  List<CameraDescription>? cameras;
  int selectedCameraIndex = 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Initialize target language based on locale if we wanted, but static "Hindi" for now as requested.
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerService.dispose();
    // Do not dispose _ocrService here as it is a singleton and may be used elsewhere.
    // _ocrService.dispose();
    disposeCamera();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      initializeCamera();
    }
  }

  // --- Camera Methods ---

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        // Default to back camera
        selectedCameraIndex = 0;
        await _initCamera(cameras![selectedCameraIndex]);
      } else {
        Get.snackbar("Error", "No cameras found");
      }
    } catch (e) {
      // Handle camera initialization errors (e.g. permission denied) gracefully
      print("Failed to initialize camera: $e");
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    if (cameraController != null) {
      await cameraController!.dispose();
    }

    cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    cameraController!.addListener(() {
      if (HasListeners) update(); // Safe update
    });

    try {
      await cameraController!.initialize();
      isCameraInitialized.value = true;
    } catch (e) {
      Get.snackbar("Error", "Camera init error: $e");
    }
  }

  Future<void> disposeCamera() async {
    if (cameraController != null) {
      await cameraController!.dispose();
      cameraController = null;
    }
    isCameraInitialized.value = false;
  }

  void toggleFlash() async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;

    try {
      isFlashOn.value = !isFlashOn.value;
      await cameraController!.setFlashMode(
        isFlashOn.value ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      print("Flash toggle error: $e");
    }
  }

  void switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    selectedCameraIndex = (selectedCameraIndex + 1) % cameras!.length;
    isCameraInitialized.value = false;
    await _initCamera(cameras![selectedCameraIndex]);
  }

  void toggleAutoMode() {
    isAutoMode.value = !isAutoMode.value;
  }

  void setScannerMode(ScannerMode mode) {
    currentMode.value = mode;
  }

  void setTargetLanguage(String code) {
    if (supportedLanguages.containsKey(code)) {
      targetLanguageCode.value = code;
      targetLanguage.value = supportedLanguages[code]!;
    }
  }

  void toggleBatchMode() {
    isBatchMode.value = !isBatchMode.value;
  }

  void setFilter(FilterType filter) {
    selectedLiveFilter.value = filter;
  }

  void toggleAutoCrop() {
    isAutoCropEnabled.value = !isAutoCropEnabled.value;
    Get.snackbar(
      "Auto-Crop",
      isAutoCropEnabled.value ? "Enabled" : "Disabled",
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.white70,
    );
  }

  Future<void> captureImage(BuildContext context) async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;

    if (isScanning.value) return; // Prevent double taps

    try {
      isScanning.value = true;
      final XFile image = await cameraController!.takePicture();
      String finalPath = image.path;

      // 1. Apply Live Filter if needed
      if (selectedLiveFilter.value != FilterType.original) {
        finalPath = await ImageProcessor.applyFilter(
          finalPath,
          selectedLiveFilter.value,
        );
      }

      // 2. Add to list
      scannedPages.add(finalPath);

      // 3. Auto-Rotate logic (Optimistic)
      _performAutoRotation([finalPath]);

      // 4. Flow Logic
      if (isBatchMode.value) {
        // Stay in camera
        Get.snackbar(
          "Captured",
          "Page ${scannedPages.length} added",
          duration: const Duration(milliseconds: 800),
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
          backgroundColor: Colors.white70,
        );
      } else {
        // Single Mode: Go to Review/Crop immediately
        if (isAutoCropEnabled.value) {
          // Should ideally go to crop screen, but for now go back to review to keep it simple
          Get.back();
        } else {
          Get.back();
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Capture failed: $e");
    } finally {
      isScanning.value = false;
    }
  }

  /// Captures an image and extracts text (returns text, no UI)
  Future<String> scanAndReturnText() async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return '';
    try {
      isScanning.value = true;
      final XFile image = await cameraController!.takePicture();

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final text = await _ocrService.extractText(image.path);

      Get.back(); // Close loading
      return text;
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Error", "Text scan failed: $e");
      return '';
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> scanForOcr(BuildContext context) async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;
    try {
      isScanning.value = true;
      // 1. Capture
      final XFile image = await cameraController!.takePicture();

      // 2. Show Loading
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // 3. Extract Text
      final text = await _ocrService.extractText(image.path);

      Get.back(); // Close loading

      // 4. Show Result in Dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Quick OCR Result"),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Get.back();
                Get.snackbar("Copied", "Text copied to clipboard");
              },
              child: const Text("Copy"),
            ),
            TextButton(onPressed: () => Get.back(), child: const Text("Close")),
          ],
        ),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Error", "OCR Scan failed: $e");
    } finally {
      isScanning.value = false;
    }
  }

  bool get HasListeners => hasListeners; // Helper for GetX

  /// Launches the camera scanner
  Future<void> startScan() async {
    try {
      isScanning.value = true;
      // Ensure local camera is released before launching external scanner
      await disposeCamera();

      final results = await _scannerService.scanDocument();

      if (results.isNotEmpty) {
        scannedPages.addAll(results);
        print('Scanned ${results.length} pages');

        // --- AI AUTO RUN: Auto-Rotate ---
        // Run in background to avoid blocking UI immediately,
        // or notify user "Optimizing...".
        // Let's do it optimistically.
        _performAutoRotation(results);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to scan documents: $e');
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> _performAutoRotation(List<String> newPaths) async {
    for (int i = 0; i < newPaths.length; i++) {
      final path = newPaths[i];
      // 1. Detect Orientation via OCR
      final angle = await _ocrService.detectOrientation(path);

      if (angle != 0) {
        print('AI detected rotation $angle for $path');
        isProcessing.value = true;
        // 2. Rotate
        final newPath = await ImageProcessor.rotate(
          path,
          angle,
        ); // Need to expose this in ImageProcessor

        // 3. Update List (find index of original path)
        final index = scannedPages.indexOf(path);
        if (index != -1) {
          scannedPages[index] = newPath;
        }
        isProcessing.value = false;
      }
    }
  }

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

  /// Saves the current session as a PDF
  Future<String?> saveAsPdf(String fileName) async {
    if (scannedPages.isEmpty) return null;

    try {
      isProcessing.value = true;
      final directory = await getApplicationDocumentsDirectory();
      // Ensure fileName ends with .pdf
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName += '.pdf';
      }
      final outputPath = '${directory.path}/$fileName';

      // Advanced Feature: Extract text for "Searchable Transcript"
      List<String> transcripts = [];
      try {
        // Run OCR on all pages to append transcript
        // This makes it an "AI PDF"
        for (var page in scannedPages) {
          final text = await _ocrService.extractText(page);
          transcripts.add(text);
        }
      } catch (e) {
        print("OCR for PDF failed: $e");
        // Continue without transcript
      }

      await PdfBuilder.createPdfFromImages(
        imagePaths: scannedPages.toList(),
        outputPath: outputPath,
        extractedText: transcripts,
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

  /// Extracts text from a specific page
  Future<String> extractTextFromPage(int index) async {
    if (index < 0 || index >= scannedPages.length) return '';

    try {
      isProcessing.value = true;
      final text = await _ocrService.extractText(scannedPages[index]);
      return text;
    } catch (e) {
      Get.snackbar('Error', 'OCR Failed: $e');
      return '';
    } finally {
      isProcessing.value = false;
    }
  }

  /// Applies a filter to a specific page
  Future<void> enhancePage(int index, FilterType filter) async {
    if (index < 0 || index >= scannedPages.length) return;

    try {
      isProcessing.value = true;
      // Apply filter (runs in Isolate)
      final newPath = await ImageProcessor.applyFilter(
        scannedPages[index],
        filter,
      );

      // Update the list with the new path to trigger UI refresh
      scannedPages[index] = newPath;
      scannedPages.refresh(); // Force update
    } catch (e) {
      Get.snackbar('Error', 'Filter failed: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  /// Updates a page with a newly cropped image
  void updatePageWithCrop(int index, String newPath) {
    if (index < 0 || index >= scannedPages.length) return;
    scannedPages[index] = newPath;
    scannedPages.refresh();
  }

  /// Picks an image from the gallery and adds it to the scan session
  Future<void> pickFromGallery() async {
    try {
      isScanning.value = true;
      // Release camera before opening gallery (which might invoke camera intent)
      await disposeCamera();

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        scannedPages.add(image.path);
        print('Imported from gallery: ${image.path}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    } finally {
      isScanning.value = false;
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

      // Share the file
      await Share.shareXFiles([XFile(outputPath)], text: 'Scanned Document');
      await Share.shareXFiles([XFile(outputPath)], text: 'Scanned Document');
    } catch (e) {
      Get.snackbar('Error', 'Failed to share: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  /// AI Smart Naming: Generates a title based on content
  Future<String> generateSmartTitle() async {
    if (scannedPages.isEmpty) {
      return 'Scan_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      // 1. Get Text from first page
      final text = await _ocrService.extractText(scannedPages.first);
      if (text.isEmpty) return 'Scan_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Classify document to improve fallback name
      final category = _aiInsightsService.classifyDocument(text);
      String baseName = 'Scan';
      if (category != DocCategory.unknown && category != DocCategory.note) {
        // Capitalize the category name, e.g., "invoice" -> "Invoice"
        baseName = category.name.capitalizeFirst ?? category.name;
      }

      // 3. Simple Heuristics for Title extraction
      // Take first line or a line that looks like a title
      final lines = text.split('\n');
      String candidate = '';

      for (var line in lines) {
        line = line.trim();
        // Look for something substantial but not a paragraph
        if (line.isNotEmpty && line.length > 4 && line.length < 40) {
          // Skip lines that are just numbers/dates unless that's all we have
          candidate = line;
          break;
        }
      }

      if (candidate.isNotEmpty) {
        // Sanitize filename
        candidate = candidate.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        // Cap length
        if (candidate.length > 20) candidate = candidate.substring(0, 20);
        return candidate;
      }

      return '${baseName}_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'Scan_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> scanAndAnalyzeType() async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;
    try {
      isScanning.value = true;
      final XFile image = await cameraController!.takePicture();
      Get.back(); // Close loading
      detectDocumentType(image.path);
    } catch (e) {
      Get.snackbar("Error", "Analysis failed: $e");
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> scanForHandwriting() async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;
    try {
      isScanning.value = true;
      final XFile image = await cameraController!.takePicture();

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final text = await _ocrService.extractText(image.path);

      Get.back(); // Close loading

      // Navigate to specialized Handwriting Screen
      Get.to(
        () =>
            HandwritingResultScreen(imagePath: image.path, extractedText: text),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Error", "Handwriting scan failed: $e");
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> scanAndTranslate() async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;
    try {
      isScanning.value = true;
      final XFile image = await cameraController!.takePicture();

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final recognizedText = await _ocrService.extractTextBlocks(image.path);

      Get.back(); // Close loading

      if (recognizedText != null && recognizedText.blocks.isNotEmpty) {
        Get.to(
          () => TranslationResultScreen(
            imagePath: image.path,
            recognizedText: recognizedText,
            targetLanguageCode: targetLanguageCode.value,
          ),
        );
      } else {
        Get.snackbar("No Text", "Could not detect any text to translate.");
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Error", "Translation scan failed: $e");
    } finally {
      isScanning.value = false;
    }
  }

  /// Analyzes the document type from an image path
  Future<void> detectDocumentType(String imagePath) async {
    try {
      isProcessing.value = true;
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final text = await _ocrService.extractText(imagePath);
      detectedCategory.value = _aiInsightsService.classifyDocument(text);
      detectedEntities.assignAll(_aiInsightsService.extractEntities(text));

      Get.back(); // Close loading

      _showDetectionResultSheet();
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      print("Detection failed: $e");
    } finally {
      isProcessing.value = false;
    }
  }

  void _showDetectionResultSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Smart Document Recognition",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(20),
            // Simulated Loading or Result
            Obx(
              () => _buildDetectionResultRow(
                "Inbox/Note",
                detectedCategory.value == DocCategory.note,
              ),
            ),
            const Gap(10),
            Obx(
              () => _buildDetectionResultRow(
                "Invoice",
                detectedCategory.value == DocCategory.invoice,
              ),
            ),
            const Gap(10),
            Obx(
              () => _buildDetectionResultRow(
                "Business Card",
                detectedCategory.value == DocCategory.businessCard,
              ),
            ),
            const Gap(10),
            Obx(
              () => _buildDetectionResultRow(
                "ID Card",
                detectedCategory.value == DocCategory.idCard,
              ),
            ),
            const Gap(20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                onPressed: () => Get.back(),
                child: const Text(
                  "Done",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionResultRow(String label, bool isDetected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDetected ? Colors.blueAccent.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: isDetected ? Border.all(color: Colors.blueAccent) : null,
      ),
      child: Row(
        children: [
          Icon(
            isDetected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDetected ? Colors.blueAccent : Colors.grey,
          ),
          const Gap(12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isDetected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isDetected) ...[
            const Spacer(),
            const Text(
              "Detected",
              style: TextStyle(color: Colors.blueAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
