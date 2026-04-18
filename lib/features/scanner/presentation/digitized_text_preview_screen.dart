import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class DigitizedTextPreviewScreen extends StatefulWidget {
  final String imagePath;
  final Function(String) onSave;

  const DigitizedTextPreviewScreen({
    super.key,
    required this.imagePath,
    required this.onSave,
  });

  @override
  State<DigitizedTextPreviewScreen> createState() =>
      _DigitizedTextPreviewScreenState();
}

class _DigitizedTextPreviewScreenState
    extends State<DigitizedTextPreviewScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  bool _isProcessing = true;
  RecognizedText? _recognizedText;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _processImage() async {
    try {
      // 1. Get Image size
      final data = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frameInfo = await codec.getNextFrame();
      _image = frameInfo.image;

      // 2. Run Text Recognition
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      _recognizedText = await _textRecognizer.processImage(inputImage);
      
    } catch (e) {
      Get.snackbar('Error', 'Failed to digitize text: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _saveDigitizedVersion() async {
    try {
      setState(() => _isProcessing = true);
      
      // Capture the digital recreation as an image
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      // We render it at original logical pixel ratio 1.0 since we made the container native size
      ui.Image capturedImage = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
          await capturedImage.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/Digitized_${DateTime.now().millisecondsSinceEpoch}.png';
      
      final file = File(outPath);
      await file.writeAsBytes(pngBytes);

      widget.onSave(outPath);
      Get.back(); // close the screen
      
    } catch (e) {
      Get.snackbar('Error', 'Failed to save digital copy: $e');
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1E),
      appBar: AppBar(
        title: Text(
          'DIGITIZED TEXT',
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00FFCC)),
                  const SizedBox(height: 16),
                  Text(
                    'Extracting text layout...',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(2000),
                    minScale: 0.1,
                    maxScale: 2.0,
                    constrained: false, // Allows full native size
                    child: RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        color: Colors.white,
                        width: _image!.width.toDouble(),
                        height: _image!.height.toDouble(),
                        child: Stack(
                          children: _buildTextBlocks(),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bottom Bar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060610).withValues(alpha: 0.95),
                    border: const Border(
                      top: BorderSide(color: Color(0x339B59FF), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveDigitizedVersion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFCC),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFF00FFCC).withValues(alpha: 0.5),
                          ),
                          child: Text(
                            'Save Digital Copy',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildTextBlocks() {
    if (_recognizedText == null || _image == null) return [];

    List<Widget> textWidgets = [];

    for (TextBlock block in _recognizedText!.blocks) {
      for (TextLine line in block.lines) {
        final rect = line.boundingBox;
        
        // ML Kit gives us bounding boxes. We try to guess the font size.
        // It's often roughly the height of the bounding box.
        final fontSize = rect.height * 0.85;

        // The exact position from top and left
        final left = rect.left;
        final top = rect.top;
        final width = rect.width;

        textWidgets.add(
          Positioned(
            left: left,
            top: top,
            width: width + (fontSize * 2), // small buffer to avoid wrapping
            child: Text(
              line.text,
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        );
      }
    }
    
    return textWidgets;
  }
}
