import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:translator/translator.dart';
import 'package:get/get.dart';

class TranslationResultScreen extends StatefulWidget {
  final String imagePath;
  final RecognizedText recognizedText;
  final String targetLanguageCode;

  const TranslationResultScreen({
    super.key,
    required this.imagePath,
    required this.recognizedText,
    required this.targetLanguageCode,
  });

  @override
  State<TranslationResultScreen> createState() =>
      _TranslationResultScreenState();
}

class _TranslationResultScreenState extends State<TranslationResultScreen> {
  final GoogleTranslator translator = GoogleTranslator();
  // Map of original text block to translated text
  final Map<TextBlock, String> _translations = {};
  bool _isLoading = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
    _translateText();
  }

  void _resolveImageSize() {
    final image = Image.file(File(widget.imagePath));
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            if (mounted) {
              setState(() {
                _imageSize = Size(
                  info.image.width.toDouble(),
                  info.image.height.toDouble(),
                );
              });
            }
          }),
        );
  }

  Future<void> _translateText() async {
    try {
      // Create a list of futures to translate all blocks in parallel
      await Future.wait(
        widget.recognizedText.blocks.map((block) async {
          if (block.text.trim().isEmpty) return;
          try {
            final translation = await translator.translate(
              block.text,
              to: widget.targetLanguageCode,
            );
            if (mounted) {
              setState(() {
                _translations[block] = translation.text;
              });
            }
          } catch (e) {
            print("Translation failed for block: ${block.text} - $e");
          }
        }),
      );
    } catch (e) {
      print("Translation process error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
          // 1. The Image & Overlay in a zoomable view
          if (_imageSize != null)
            InteractiveViewer(
              minScale: 0.1,
              maxScale: 5.0,
              // Use Center and FittedBox to ensure the initial view fits the screen
              // while preserving the coordinate system of the original image size.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _imageSize!.width,
                    height: _imageSize!.height,
                    child: Stack(
                      children: [
                        Image.file(
                          File(widget.imagePath),
                          width: _imageSize!.width,
                          height: _imageSize!.height,
                          fit: BoxFit.fill,
                        ),
                        ..._buildTranslationWidgets(),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // 2. Top Bar (Back Button)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Get.back(),
              ),
            ),
          ),

          // 3. Loading Indicator
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      "Translating...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTranslationWidgets() {
    return _translations.entries.map((entry) {
      final block = entry.key;
      final text = entry.value;
      final rect = block.boundingBox;

      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(
              0xFFFFFBE6,
            ).withOpacity(0.95), // Light beige background, nice for reading
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft, // Align text nicely
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
