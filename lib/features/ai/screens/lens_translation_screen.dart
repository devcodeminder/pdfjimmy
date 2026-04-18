import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart';
import 'package:path_provider/path_provider.dart';

class LensTranslationScreen extends StatefulWidget {
  final File? initialImage;

  const LensTranslationScreen({super.key, this.initialImage});

  @override
  State<LensTranslationScreen> createState() => _LensTranslationScreenState();
}

class _LensTranslationScreenState extends State<LensTranslationScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isCaptured = false;
  String? _error;

  File? _capturedImage;
  Size? _imageSize; // Size of the original captured image
  List<_TranslatedBlock> _translatedBlocks = [];

  final GlobalKey _boundaryKey = GlobalKey();

  String _selectedToLanguage = 'ta'; // Tamil by default
  final Map<String, String> _languages = {
    'en': 'English',
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
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialImage != null) {
      _isInitializing = false;
      _cameraController = null; // No camera needed
      _processImageFile(widget.initialImage!);
    } else {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = "No cameras found.");
        return;
      }

      // Try finding back camera
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      // Lock to portrait to keep things simple
      await _cameraController!.lockCaptureOrientation();

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Camera init error: $e");
      }
    }
  }

  Future<void> _captureFromCamera() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      final XFile photo = await _cameraController!.takePicture();
      _cameraController!.pausePreview();
      await _processImageFile(File(photo.path));
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _cameraController?.pausePreview();
        await _processImageFile(File(image.path));
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _processImageFile(File file) async {
    setState(() {
      _isProcessing = true;
      _capturedImage = file;
    });

    try {
      _imageSize = await _getImageSize(file);

      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      List<_TranslatedBlock> blocks = recognizedText.blocks
          .map(
            (b) => _TranslatedBlock(originalText: b.text, rect: b.boundingBox),
          )
          .toList();

      final translator = GoogleTranslator();
      if (blocks.isNotEmpty) {
        await Future.wait(
          blocks.map((block) async {
            if (block.originalText.trim().isEmpty) return;
            try {
              final translation = await translator.translate(
                block.originalText,
                to: _selectedToLanguage,
              );
              block.translatedText = translation.text;
            } catch (e) {
              debugPrint("Translation error for '${block.originalText}': $e");
            }
          }),
        );
      }

      if (mounted) {
        setState(() {
          _translatedBlocks = blocks;
          _isCaptured = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _retranslateCurrentBlocks() async {
    if (_translatedBlocks.isEmpty) return;
    setState(() => _isProcessing = true);
    final translator = GoogleTranslator();
    
    await Future.wait(
      _translatedBlocks.map((block) async {
        if (block.originalText.trim().isEmpty) return;
        try {
          final translation = await translator.translate(
            block.originalText,
            to: _selectedToLanguage,
          );
          block.translatedText = translation.text;
        } catch (e) {
          debugPrint("Translation error for '${block.originalText}': $e");
        }
      }),
    );

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _handleError(Object e) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _error = "Processing failed: $e";
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      _discardCapture();
    }
  }

  void _discardCapture() {
    if (widget.initialImage != null) {
      // If we launched exclusively for this image, discard means closing the screen
      Navigator.pop(context);
      return;
    }
    _cameraController?.resumePreview();
    setState(() {
      _isCaptured = false;
      _capturedImage = null;
      _translatedBlocks.clear();
      _imageSize = null;
    });
  }

  Future<Size> _getImageSize(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  void _copyAllText() {
    final fullText = _translatedBlocks
        .where((b) => b.translatedText != null)
        .map((b) => b.translatedText)
        .join('\n');
    if (fullText.trim().isNotEmpty) {
      Clipboard.setData(ClipboardData(text: fullText));
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied to clipboard!',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          backgroundColor: const Color(0xFF00FFCC),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  Future<void> _saveImage() async {
    try {
      RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final savePath =
          '${dir.path}/Translated_Image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(savePath);
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Image saved to Documents/Files!',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            backgroundColor: const Color(0xFF00FFCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview OR Captured Frozen Image
          if (_isInitializing)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_error != null)
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else
            GestureDetector(
              onLongPress: _isCaptured ? _copyAllText : null,
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!_isCaptured && widget.initialImage == null) _buildCameraView(),
                    if (_isCaptured && _capturedImage != null && _imageSize != null)
                      _buildCapturedView(),
                  ],
                ),
              ),
            ),

          // 2. Top Gradient HUD (Language Picker)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 24,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Back Button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Language Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white38),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF00FFCC),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedToLanguage,
                            dropdownColor: const Color(0xFF1E293B),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            onChanged: _isProcessing
                                ? null
                                : (newVal) {
                                    if (newVal != null && newVal != _selectedToLanguage) {
                                      setState(() {
                                        _selectedToLanguage = newVal;
                                      });
                                      if (_isCaptured) {
                                        _retranslateCurrentBlocks();
                                      }
                                    }
                                  },
                            items: _languages.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
            ),
          ),

          // 3. Bottom Controls (Shutter / Discard / Save)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 32,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: _isCaptured
                  ? _buildCapturedControls()
                  : _buildLiveControls(),
            ),
          ),

          // 4. Processing Overlay
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00FFCC)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFCC).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const CircularProgressIndicator(
                        color: Color(0xFF00FFCC),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Detecting Text...',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ).animate().fade(duration: 500.ms).shimmer(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(child: CameraPreview(_cameraController!)),
    );
  }

  Widget _buildCapturedView() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6.0, // Allow huge zoom
      panEnabled: true,
      scaleEnabled: true,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Find the best fit for the image inside the screen constraints
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final imgWidth = _imageSize!.width;
            final imgHeight = _imageSize!.height;

            final screenAspect = screenWidth / screenHeight;
            final imgAspect = imgWidth / imgHeight;

            double displayWidth;
            double displayHeight;

            if (screenAspect > imgAspect) {
              // Constrained by height
              displayHeight = screenHeight;
              displayWidth = displayHeight * imgAspect;
            } else {
              // Constrained by width
              displayWidth = screenWidth;
              displayHeight = displayWidth / imgAspect;
            }

            final scaleX = displayWidth / imgWidth;
            final scaleY = displayHeight / imgHeight;

            return SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base Image (perfectly bounds the SizedBox)
                  Image.file(_capturedImage!, fit: BoxFit.fill),
                  
                  // Text Overlays perfectly placed on the image
                  ..._translatedBlocks.map((block) {
                    if (block.translatedText == null || block.translatedText!.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    double left = block.rect.left * scaleX;
                    double top = block.rect.top * scaleY;
                    double width = block.rect.width * scaleX;
                    double height = block.rect.height * scaleY;

                    // Ensure blocks don't go exactly out of image boundaries
                    if (left < 0) left = 0;
                    if (top < 0) top = 0;
                    if (left + width > displayWidth) width = displayWidth - left;

                    if (width < 10) return const SizedBox.shrink(); // Hide unreadable tiny artifacts

                    return Positioned(
                      left: left,
                      top: top,
                      width: width,
                      // Omitting height allows dynamic growth for long text
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4), // Scaled border radius visually
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          block.translatedText!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                            fontSize: (height * 0.45).clamp(8.0, 32.0),
                            height: 1.3,
                          ),
                        ),
                      ).animate().fade(duration: 400.ms),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Gallery Button
        Container(
          margin: const EdgeInsets.only(right: 32),
          child: InkWell(
            onTap: _pickFromGallery,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54),
              ),
              child: const Icon(Icons.photo_library_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
        ),

        // Premium Lens Shutter Button
        GestureDetector(
          onTap: _captureFromCamera,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.translate_rounded,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
          ),
        ).animate().scale(curve: Curves.elasticOut),

        // Dummy Space to balance Row
        const SizedBox(width: 88),
      ],
    );
  }

  Widget _buildCapturedControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Helper text for copying
        Text(
          'Long press anywhere to copy all text',
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ).animate().fade(delay: 500.ms),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomBtn(
              icon: Icons.close_rounded,
              label: 'Discard',
              color: Colors.white54,
              onTap: _discardCapture,
            ),
            _buildBottomBtn(
              icon: Icons.copy_rounded,
              label: 'Copy Text',
              color: const Color(0xFF0280F8),
              onTap: _copyAllText,
            ),
            _buildBottomBtn(
              icon: Icons.save_alt_rounded,
              label: 'Save Image',
              color: const Color(0xFF00FFCC),
              onTap: _saveImage,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _TranslatedBlock {
  final String originalText;
  String? translatedText;
  final Rect rect;

  _TranslatedBlock({required this.originalText, required this.rect});
}
