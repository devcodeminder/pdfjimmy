import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdfjimmy/services/image_intelligence_service.dart';
import 'package:pdfjimmy/services/ocr_engine_service.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:translator/translator.dart';

/// Document Scanner Screen
/// Features:
/// - Camera/Gallery image capture
/// - Auto edge detection
/// - Perspective correction
/// - Shadow removal
/// - De-skew
/// - Noise reduction
/// - Adaptive contrast (B&W, Magic Color)
/// - OCR text extraction
/// - Save as PDF
/// OCR Mode Enum
enum OcrMode { standard, handwriting, table }

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({Key? key}) : super(key: key);

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final ImageIntelligenceService _imageService = ImageIntelligenceService();
  final OcrEngineService _ocrService = OcrEngineService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _originalImage;
  Uint8List? _processedImage;
  String? _extractedText;
  String? _translatedText;
  bool _isProcessing = false;
  bool _isTranslating = false;
  double _processingProgress = 0.0;
  String _processingStatus = '';
  String _selectedLanguage = 'hi'; // Hindi by default

  // Enhancement options - All enabled for "Automatic" mode
  bool _autoEdgeDetect = true;
  bool _correctPerspective = true;
  bool _removeShadows = true;
  bool _deSkew = true;
  bool _reduceNoise = true;
  bool _enhanceContrast = true;
  bool _showAdvancedOptions = false;
  String _contrastMode = 'bw'; // 'bw' or 'color'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 Document Scanner'),
        actions: [
          if (_extractedText != null && _extractedText!.isNotEmpty)
            IconButton(
              icon: _isTranslating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.translate),
              onPressed: _isTranslating ? null : () => _showLanguageSelector(),
              tooltip: 'Translate Text',
            ),
          if (_processedImage != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDocument,
              tooltip: 'Save as PDF',
            ),
          if (_processedImage != null)
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: _showOCROptions,
              tooltip: 'Extract Text (OCR)',
            ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview
          Expanded(flex: 3, child: _buildImagePreview(isDark)),

          // Extracted Text Preview (if available)
          if (_extractedText != null && _extractedText!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.text_fields,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Extracted Text',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isTranslating
                            ? null
                            : _showLanguageSelector,
                        icon: _isTranslating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.translate, size: 18),
                        label: Text(
                          _isTranslating ? 'Translating...' : 'Translate',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _extractedText!.length > 150
                        ? '${_extractedText!.substring(0, 150)}...'
                        : _extractedText!,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // Controls
          Expanded(flex: 2, child: _buildControls(primaryColor, isDark)),
        ],
      ),
      floatingActionButton: _originalImage == null
          ? FloatingActionButton.extended(
              onPressed: _showImageSourceDialog,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Document'),
            )
          : null,
    );
  }

  Widget _buildImagePreview(bool isDark) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _processingProgress,
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _processingStatus,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_processingProgress * 100).toInt()}%',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    if (_processedImage != null || _originalImage != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Image
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  _processedImage ?? _originalImage!,
                  fit: BoxFit.contain,
                ),
              ),

              // Comparison toggle
              if (_processedImage != null && _originalImage != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildComparisonButton('Original', false),
                        _buildComparisonButton('Enhanced', true),
                      ],
                    ),
                  ),
                ),

              // OCR Text overlay
              if (_extractedText != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.text_fields,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Extracted Text',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white),
                              onPressed: () {
                                // Copy to clipboard
                                Get.snackbar(
                                  'Copied',
                                  'Text copied to clipboard',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _extractedText!.length > 200
                              ? '${_extractedText!.substring(0, 200)}...'
                              : _extractedText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ).animate().fadeIn();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 120,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No document scanned',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to scan a document',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonButton(String label, bool showProcessed) {
    final isSelected = showProcessed
        ? _processedImage != null
        : _processedImage == null && _originalImage != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (showProcessed) {
              // Show processed
            } else {
              // Show original
              final temp = _processedImage;
              _processedImage = null;
              Future.delayed(const Duration(milliseconds: 100), () {
                setState(() {
                  _processedImage = temp;
                });
              });
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(Color primaryColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Advanced Options Header as a Toggle
            InkWell(
              onTap: () =>
                  setState(() => _showAdvancedOptions = !_showAdvancedOptions),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Automatic Intelligence',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showAdvancedOptions
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),

            if (!_showAdvancedOptions)
              Padding(
                padding: const EdgeInsets.only(left: 32.0, bottom: 16.0),
                child: Text(
                  'Auto Edge, Perspective, Shadow Removal & De-skew enabled.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),

            // Enhancement toggles - Only shown if advanced is expanded
            if (_showAdvancedOptions) ...[
              const SizedBox(height: 8),
              _buildEnhancementToggle(
                'Perspective Correction',
                'Fix camera angle and distortion',
                Icons.crop_rotate,
                _correctPerspective,
                (value) => setState(() => _correctPerspective = value),
              ),
              _buildEnhancementToggle(
                'Shadow Removal',
                'Remove shadows from document',
                Icons.wb_sunny_outlined,
                _removeShadows,
                (value) => setState(() => _removeShadows = value),
              ),
              _buildEnhancementToggle(
                'De-skew',
                'Straighten tilted documents',
                Icons.straighten,
                _deSkew,
                (value) => setState(() => _deSkew = value),
              ),
              _buildEnhancementToggle(
                'Noise Reduction',
                'Remove grain and artifacts',
                Icons.blur_off,
                _reduceNoise,
                (value) => setState(() => _reduceNoise = value),
              ),
              _buildEnhancementToggle(
                'Edge Detection',
                'Detect document edges',
                Icons.border_outer,
                _autoEdgeDetect,
                (value) => setState(() => _autoEdgeDetect = value),
              ),

              const Divider(height: 32),

              // Contrast Mode
              Row(
                children: [
                  Icon(Icons.contrast, color: primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Contrast Mode',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildContrastModeButton(
                      'Black & White',
                      Icons.filter_b_and_w,
                      'bw',
                      primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildContrastModeButton(
                      'Magic Color',
                      Icons.palette,
                      'color',
                      primaryColor,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            if (_originalImage != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processImage,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Enhance Document'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.refresh),
                      label: const Text('New Scan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().slideY(
      begin: 1.0,
      end: 0,
      duration: 600.ms,
      curve: Curves.easeOutQuart,
    );
  }

  Widget _buildEnhancementToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: value
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300]!,
                width: value ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: value
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: value ? null : Colors.grey[600],
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContrastModeButton(
    String label,
    IconData icon,
    String mode,
    Color primaryColor,
  ) {
    final isSelected = _contrastMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _contrastMode = mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 32),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo of the document'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 32),
              title: const Text('Gallery'),
              subtitle: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _originalImage = bytes;
          _processedImage = null;
          _extractedText = null;
        });

        // Auto-process automatically
        _processImage();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _processImage() async {
    if (_originalImage == null) return;

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Starting enhancement...';
    });

    try {
      Uint8List processed = _originalImage!;
      int totalSteps = 0;
      int currentStep = 0;

      // Count enabled steps
      if (_deSkew) totalSteps++;
      if (_correctPerspective) totalSteps++;
      if (_removeShadows) totalSteps++;
      if (_reduceNoise) totalSteps++;
      if (_autoEdgeDetect) totalSteps++;
      if (_enhanceContrast) totalSteps++;

      // De-skew
      if (_deSkew) {
        setState(() {
          _processingStatus = 'Straightening document...';
          _processingProgress = currentStep / totalSteps;
        });
        processed = await _imageService.deSkew(processed);
        currentStep++;
      }

      // Perspective correction
      if (_correctPerspective) {
        setState(() {
          _processingStatus = 'Correcting perspective...';
          _processingProgress = currentStep / totalSteps;
        });
        processed = await _imageService.correctPerspective(processed);
        currentStep++;
      }

      // Shadow removal
      if (_removeShadows) {
        setState(() {
          _processingStatus = 'Removing shadows...';
          _processingProgress = currentStep / totalSteps;
        });
        processed = await _imageService.removeShadows(processed);
        currentStep++;
      }

      // Noise reduction
      if (_reduceNoise) {
        setState(() {
          _processingStatus = 'Reducing noise...';
          _processingProgress = currentStep / totalSteps;
        });
        processed = await _imageService.reduceNoise(processed);
        currentStep++;
      }

      // Edge detection
      if (_autoEdgeDetect) {
        setState(() {
          _processingStatus = 'Detecting edges...';
          _processingProgress = currentStep / totalSteps;
        });
        processed = await _imageService.detectEdges(processed);
        currentStep++;
      }

      // Contrast enhancement
      if (_enhanceContrast) {
        setState(() {
          _processingStatus = 'Enhancing contrast...';
          _processingProgress = currentStep / totalSteps;
        });

        if (_contrastMode == 'bw') {
          processed = await _imageService.applyAdaptiveContrastBW(processed);
        } else {
          processed = await _imageService.applyMagicColor(processed);
        }
        currentStep++;
      }

      setState(() {
        _processedImage = processed;
        _isProcessing = false;
        _processingProgress = 1.0;
        _processingStatus = 'Complete!';
      });

      Get.snackbar(
        'Success',
        'Document enhanced successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      Get.snackbar(
        'Error',
        'Failed to process image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showOCROptions() {
    if (_processedImage == null && _originalImage == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OCR Engine Options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the extraction mode best suited for your document.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Standard OCR
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description, color: Colors.blue),
              ),
              title: const Text('Standard Text'),
              subtitle: const Text('Best for printed documents & letters'),
              onTap: () {
                Navigator.pop(context);
                _performOCR(OcrMode.standard);
              },
            ),
            const SizedBox(height: 8),

            // Handwriting (Premium)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note, color: Colors.purple),
              ),
              title: const Row(
                children: [
                  Text('Handwriting'),
                  SizedBox(width: 8),
                  Chip(
                    label: Text(
                      'PREMIUM',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: Colors.purple,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              subtitle: const Text('Recognize handwritten notes & scripts'),
              onTap: () {
                Navigator.pop(context);
                _performOCR(OcrMode.handwriting);
              },
            ),
            const SizedBox(height: 8),

            // Table Extraction
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart, color: Colors.green),
              ),
              title: const Text('Table Extraction'),
              subtitle: const Text('Preserve row & column structure'),
              onTap: () {
                Navigator.pop(context);
                _performOCR(OcrMode.table);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performOCR([OcrMode mode = OcrMode.standard]) async {
    if (_processedImage == null && _originalImage == null) return;

    setState(() {
      _isProcessing = true;
      _processingStatus = mode == OcrMode.handwriting
          ? 'Reading handwriting...'
          : mode == OcrMode.table
          ? 'Analyzing table structure...'
          : 'Extracting text...';
      _processingProgress = 0.5;
      _extractedText = null; // Clear previous
    });

    try {
      final imageToProcess = _processedImage ?? _originalImage!;
      String resultText = '';
      double confidence = 0.0;

      if (mode == OcrMode.standard) {
        final result = await _ocrService.performOcr(
          imageToProcess,
          detectLanguage: true,
          preserveLayout: true,
        );
        resultText = result.text;
        confidence = result.confidence;
      } else if (mode == OcrMode.handwriting) {
        final result = await _ocrService.recognizeHandwriting(imageToProcess);
        resultText = result.text;
        confidence = result.confidence;
      } else if (mode == OcrMode.table) {
        final result = await _ocrService.extractTables(imageToProcess);
        // Format table data to string
        final buffer = StringBuffer();
        for (var i = 0; i < result.tables.length; i++) {
          buffer.writeln('Table ${i + 1}:');
          final table = result.tables[i];
          for (var row in table.rows) {
            buffer.writeln('| ${row.join(' | ')} |');
          }
          buffer.writeln('\n');
        }
        resultText = buffer.toString();
        if (resultText.isEmpty) resultText = "No tables detected.";
        confidence = 0.9; // Approximate
      }

      setState(() {
        _extractedText = resultText;
        _isProcessing = false;
      });

      Get.snackbar(
        'Success',
        'Text recognized with ${(confidence).toStringAsFixed(1)}% confidence',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      Get.snackbar(
        'OCR Job Failed',
        'AI Server Error: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _saveDocument() async {
    if (_processedImage == null && _originalImage == null) return;

    try {
      // Create PDF document
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();

      // Decode image
      final imageToSave = _processedImage ?? _originalImage!;
      final decodedImage = img.decodeImage(imageToSave);

      if (decodedImage != null) {
        // Add image to PDF
        final pdfImage = PdfBitmap(imageToSave);
        page.graphics.drawImage(
          pdfImage,
          Rect.fromLTWH(
            0,
            0,
            page.getClientSize().width,
            page.getClientSize().height,
          ),
        );
      }

      // Save PDF
      final bytes = await document.save();
      document.dispose();

      // Get save location
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'scanned_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = path.join(directory.path, fileName);

      // Write file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      Get.snackbar(
        'Saved',
        'Document saved to: $filePath',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save document: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _reset() {
    setState(() {
      _originalImage = null;
      _processedImage = null;
      _extractedText = null;
      _translatedText = null;
      _isProcessing = false;
      _processingProgress = 0.0;
      _processingStatus = '';
    });
  }

  void _showLanguageSelector() {
    final languages = {
      'hi': 'Hindi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'gu': 'Gujarati',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'pa': 'Punjabi',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh-cn': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
      'ru': 'Russian',
      'en': 'English',
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Translation Language',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: languages.entries.map((entry) {
                  return ListTile(
                    leading: Icon(
                      Icons.translate,
                      color: _selectedLanguage == entry.key
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                    title: Text(entry.value),
                    trailing: _selectedLanguage == entry.key
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLanguage = entry.key;
                      });
                      Navigator.pop(context);
                      _translateText();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _translateText() async {
    if (_extractedText == null || _extractedText!.trim().isEmpty) {
      Get.snackbar(
        'No Text',
        'Please perform OCR first to extract text',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isTranslating = true;
      _translatedText = null;
    });

    try {
      final translator = GoogleTranslator();

      // Split text into chunks if too long
      const maxChunkSize = 4500;
      final chunks = <String>[];

      for (int i = 0; i < _extractedText!.length; i += maxChunkSize) {
        final end = (i + maxChunkSize < _extractedText!.length)
            ? i + maxChunkSize
            : _extractedText!.length;
        chunks.add(_extractedText!.substring(i, end));
      }

      // Translate each chunk
      final translatedChunks = <String>[];
      for (final chunk in chunks) {
        final translated = await translator.translate(
          chunk,
          to: _selectedLanguage,
        );
        translatedChunks.add(translated.text);

        // Small delay to avoid rate limiting
        if (chunks.length > 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      setState(() {
        _translatedText = translatedChunks.join(' ');
        _isTranslating = false;
      });

      // Show translated text in dialog
      _showTranslationDialog();
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });

      Get.snackbar(
        'Translation Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _showTranslationDialog() {
    final languages = {
      'hi': 'Hindi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'gu': 'Gujarati',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'pa': 'Punjabi',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh-cn': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
      'ru': 'Russian',
      'en': 'English',
    };

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.translate, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Translated to ${languages[_selectedLanguage]}'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _translatedText ?? '',
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _translatedText ?? ''));
              Get.back();
              Get.snackbar(
                'Copied',
                'Translation copied to clipboard',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }
}
