import 'dart:io';
import 'package:flutter/material.dart';

import 'package:translator/translator.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as path;

import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

class _PageTranslationState {
  final int pageIndex;
  bool isTranslating = false;
  String? error;
  File? imageFile;
  Size? imageSize; // Cached size for layout
  List<_TranslatedBlock> overlays = [];
  bool isTranslated = false;

  _PageTranslationState(this.pageIndex);
}

class AITranslationScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int? initialPage;

  const AITranslationScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.initialPage,
  });

  @override
  State<AITranslationScreen> createState() => _AITranslationScreenState();
}

class _AITranslationScreenState extends State<AITranslationScreen> {
  String _selectedLanguage = 'hi'; // Hindi by default
  bool _isInitializing = true; // Use this for initial file setup only
  String? _globalError;
  int _totalPages = 0;

  // Page Controller
  late PageController _pageController;
  int _currentPageIndex = 0;

  bool _showOriginal = false;

  // Per-page state management
  final Map<int, _PageTranslationState> _pageStates = {};

  // For non-PDF files (Legacy/Simple mode)
  String? _simpleTranslatedText;
  bool _isSimpleMode = false;

  bool _isVertical = true; // Vertical view by default as requested
  final Map<int, TransformationController> _transformationControllers = {};
  ScrollPhysics _pagePhysics = const BouncingScrollPhysics();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    // Start page is 0-indexed for PageView, widget.initialPage is 1-indexed usually
    int startPage = (widget.initialPage != null && widget.initialPage! > 0)
        ? widget.initialPage! - 1
        : 0;
    _currentPageIndex = startPage;
    _pageController = PageController(initialPage: startPage);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDocument();
    });
  }

  @override
  void dispose() {
    for (var controller in _transformationControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

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

  Future<void> _initializeDocument() async {
    setState(() {
      _isInitializing = true;
      _globalError = null;
    });

    try {
      final extension = path.extension(widget.filePath).toLowerCase();

      if (extension == '.pdf') {
        final file = File(widget.filePath);
        final bytes = await file.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        _totalPages = document.pages.count;
        document.dispose();

        _isSimpleMode = false;

        // Trigger translation for the current page immediately
        _translatePage(_currentPageIndex);
      } else {
        // Non-PDFs (Images, Text) - Handle as pseudo "single page" or simple mode
        _totalPages = 1;
        _isSimpleMode = true;

        if (['.jpg', '.jpeg', '.png'].contains(extension)) {
          _translatePage(0);
        } else if (extension == '.txt') {
          final text = await File(widget.filePath).readAsString();
          await _translateSimpleText(text);
        }
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _globalError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _translatePage(int pageIndex) async {
    if (_pageStates.containsKey(pageIndex)) {
      final state = _pageStates[pageIndex]!;
      if (state.isTranslated || state.isTranslating) return;
    }

    if (mounted) {
      setState(() {
        _pageStates[pageIndex] = _PageTranslationState(pageIndex)
          ..isTranslating = true;
      });
    }

    try {
      final state = _pageStates[pageIndex]!;
      final extension = path.extension(widget.filePath).toLowerCase();
      List<_TranslatedBlock> blocks = [];

      // 1. Digital PDF Text Extraction
      if (extension == '.pdf') {
        final file = File(widget.filePath);
        final bytes = await file.readAsBytes();
        final pdfDoc = PdfDocument(inputBytes: bytes);
        final page = pdfDoc.pages[pageIndex];
        final pageSize = page.getClientSize();

        // 1a. Try precise line extraction first
        try {
          final extractor = PdfTextExtractor(pdfDoc);
          final lines = extractor.extractTextLines(
            startPageIndex: pageIndex,
            endPageIndex: pageIndex,
          );

          if (lines.isNotEmpty) {
            blocks = lines
                .map(
                  (line) => _TranslatedBlock(
                    originalText: line.text,
                    rect: line.bounds,
                  ),
                )
                .toList();
          } else {
            // 1b. Fallback: Extract WHOLE page text if lines failed
            // (Common in some Tamil fonts where line breaking is weird)
            final fullText = extractor.extractText(
              startPageIndex: pageIndex,
              endPageIndex: pageIndex,
            );
            if (fullText.trim().isNotEmpty) {
              // Create one big block covering the whole page
              blocks = [
                _TranslatedBlock(
                  originalText: fullText,
                  rect: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
                ),
              ];
            }
          }
        } catch (e) {
          debugPrint("PDF Text extraction failed: $e");
        }

        // 1c. Rasterize Page for Display (Background)
        // Using 300 DPI for stability
        await for (final rPage in Printing.raster(
          bytes,
          pages: [pageIndex],
          dpi: 300,
        )) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/page_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await tempFile.writeAsBytes(await rPage.toPng());
          state.imageFile = tempFile;
          break;
        }

        if (state.imageFile == null) {
          throw Exception("Failed to rasterize page");
        }
        state.imageSize = await _getImageSize(state.imageFile!);
        final double scaleX = state.imageSize!.width / pageSize.width;
        final double scaleY = state.imageSize!.height / pageSize.height;

        // Scale bounds to image size
        blocks = blocks.map((b) {
          return _TranslatedBlock(
            originalText: b.originalText,
            rect: Rect.fromLTWH(
              b.rect.left * scaleX,
              b.rect.top * scaleY,
              b.rect.width * scaleX,
              b.rect.height * scaleY,
            ),
          );
        }).toList();

        pdfDoc.dispose();
      } else if (['.jpg', '.jpeg', '.png'].contains(extension)) {
        state.imageFile = File(widget.filePath);
        state.imageSize = await _getImageSize(state.imageFile!);
      }

      // 2. OCR Fallback (Only works for Latin supported langs, NOT Tamil reliably on-device)
      if (blocks.isEmpty && state.imageFile != null) {
        final inputImage = InputImage.fromFilePath(state.imageFile!.path);
        // Try generic Latin OCR - might catch numbers or English titles
        final textRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        );
        final recognized = await textRecognizer.processImage(inputImage);
        textRecognizer.close();

        if (recognized.text.trim().isNotEmpty) {
          blocks = recognized.blocks
              .map(
                (b) =>
                    _TranslatedBlock(originalText: b.text, rect: b.boundingBox),
              )
              .toList();
        }
      }

      // 3. Translate
      final translator = GoogleTranslator();
      if (blocks.isNotEmpty) {
        // If we have one giant block, we translate it nicely
        await Future.forEach(blocks, (_TranslatedBlock block) async {
          if (block.originalText.trim().isEmpty) return;
          try {
            // For Tamil, Google Translator handles it well if input text is valid
            final translation = await translator.translate(
              block.originalText,
              to: _selectedLanguage,
            );
            block.translatedText = translation.text;
          } catch (e) {
            debugPrint("Translation error: $e");
          }
        });
      } else {
        // If still empty, maybe show a manual error block?
        state.error =
            "Could not detect text. Is this a scanned Tamil document? (OCR not supported offline)";
      }

      state.overlays = blocks;
      state.isTranslated = true;
    } catch (e) {
      debugPrint("Page $pageIndex translation failed: $e");
      if (mounted) {
        setState(() {
          _pageStates[pageIndex]?.error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _pageStates[pageIndex]?.isTranslating = false;
        });
      }
    }
  }

  Future<void> _translateSimpleText(String text) async {
    final translator = GoogleTranslator();
    setState(() {
      _simpleTranslatedText = "Translating...";
    });
    try {
      final translation = await translator.translate(
        text,
        to: _selectedLanguage,
      );
      if (mounted) {
        setState(() {
          _simpleTranslatedText = translation.text;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _simpleTranslatedText = "Error: $e");
    }
  }

  Future<Size> _getImageSize(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  Future<void> _saveTranslatedPdf() async {
    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Generating PDF..."),
                  Text(
                    "This may take a while for large files.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final document = PdfDocument();
      document.pageSettings.margins.all = 0;

      for (int i = 0; i < _totalPages; i++) {
        // 1. Ensure page is processed
        if (!_pageStates.containsKey(i) ||
            (!_pageStates[i]!.isTranslated && !_pageStates[i]!.isTranslating)) {
          await _translatePage(i);
        }

        // 2. Wait if it was already processing
        int retry = 0;
        while (_pageStates[i]?.isTranslating == true && retry < 200) {
          await Future.delayed(const Duration(milliseconds: 100));
          retry++;
        }

        final state = _pageStates[i];
        if (state == null || state.imageFile == null) {
          debugPrint("Skipping page $i due to error or null state");
          continue;
        }

        // 3. Add page to PDF
        final imageBytes = await state.imageFile!.readAsBytes();
        final PdfBitmap image = PdfBitmap(imageBytes);

        document.pageSettings.size = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
        document.pageSettings.orientation = (image.width > image.height)
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;

        final PdfPage page = document.pages.add();
        final Size pageSize = page.getClientSize();

        // Draw Base Image
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );

        // Draw Translated Overlays
        final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
        final brush = PdfSolidBrush(PdfColor(255, 255, 255, 230));
        final textBrush = PdfSolidBrush(PdfColor(0, 0, 0));

        for (var block in state.overlays) {
          if (block.translatedText != null) {
            final rect = block.rect;

            // Draw text background
            page.graphics.drawRectangle(brush: brush, bounds: rect);

            // Draw Text
            page.graphics.drawString(
              block.translatedText!,
              font,
              brush: textBrush,
              bounds: rect,
              format: PdfStringFormat(
                alignment: PdfTextAlignment.left,
                lineAlignment: PdfVerticalAlignment.top,
                wordWrap: PdfWordWrapType.word,
              ),
            );
          }
        }
      }

      // 4. Save file
      final bytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final name = widget.fileName.replaceAll(
        '.pdf',
        '_translated_$_selectedLanguage.pdf',
      );
      final path = '${dir.path}/$name';
      final file = File(path);
      await file.writeAsBytes(bytes);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $path'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        debugPrint("Error saving PDF: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Translation'),
            Text(
              _totalPages > 0
                  ? 'Page ${_currentPageIndex + 1} of $_totalPages'
                  : widget.fileName,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Save Translated PDF',
            onPressed: _saveTranslatedPdf,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _showOriginal = !_showOriginal;
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).primaryColor),
                foregroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(_showOriginal ? 'Show Translation' : 'Original'),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: 'Change Language',
            onSelected: (lang) {
              if (lang != _selectedLanguage) {
                if (mounted) {
                  setState(() {
                    _selectedLanguage = lang;
                    _pageStates.clear(); // Clear cache to re-translate
                    _translatePage(_currentPageIndex);
                  });
                }
              }
            },
            itemBuilder: (context) => _languages.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
          IconButton(
            icon: Icon(_isVertical ? Icons.view_carousel : Icons.view_agenda),
            tooltip: _isVertical
                ? 'Switch to Horizontal'
                : 'Switch to Vertical',
            onPressed: () {
              setState(() {
                _isVertical = !_isVertical;
              });
            },
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_globalError != null) {
      return Center(child: Text('Error: $_globalError'));
    }

    if (_isSimpleMode && _simpleTranslatedText != null) {
      // TXT file view
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _showOriginal ? "Original Text TODO" : _simpleTranslatedText!,
        ),
      );
    }

    // Page View Logic
    return PageView.builder(
      physics: _pagePhysics,
      scrollDirection: _isVertical ? Axis.vertical : Axis.horizontal,
      controller: _pageController,
      itemCount: _totalPages,
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
        });
        _translatePage(index); // Trigger translation if needed

        // Preload next page
        if (index + 1 < _totalPages) {
          _translatePage(index + 1);
        }
      },
      itemBuilder: (context, index) {
        return _buildPageItem(index);
      },
    );
  }

  Widget _buildPageItem(int index) {
    final state = _pageStates[index];

    // If loading for the first time
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.imageFile == null && state.isTranslating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Translating page ${index + 1}...'),
          ],
        ),
      );
    }

    if (state.imageFile == null) {
      return const Center(child: Text('Failed to load page image.'));
    }

    // Initialize controller for this page if needed
    if (!_transformationControllers.containsKey(index)) {
      _transformationControllers[index] = TransformationController();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onDoubleTapDown: (details) {
            _doubleTapDetails = details;
          },
          onDoubleTap: () {
            final controller = _transformationControllers[index];
            if (controller == null) return;

            if (controller.value.getMaxScaleOnAxis() > 1.0) {
              // Reset
              controller.value = Matrix4.identity();
              setState(() => _pagePhysics = const BouncingScrollPhysics());
            } else {
              // Zoom In
              final position = _doubleTapDetails?.localPosition;
              if (position != null) {
                controller.value = Matrix4.identity()
                  ..translate(-position.dx * 1.5, -position.dy * 1.5)
                  ..scale(2.5);
                setState(
                  () => _pagePhysics = const NeverScrollableScrollPhysics(),
                );
              }
            }
          },
          child: InteractiveViewer(
            transformationController: _transformationControllers[index],
            minScale: 1.0,
            maxScale: 10.0,
            panEnabled: true,
            scaleEnabled: true,
            onInteractionStart: (details) {
              // Disable scrolling immediately if 2 fingers involved (Pinch)
              if (details.pointerCount > 1) {
                if (_pagePhysics is! NeverScrollableScrollPhysics) {
                  setState(
                    () => _pagePhysics = const NeverScrollableScrollPhysics(),
                  );
                }
              }
            },
            onInteractionEnd: (details) {
              final scale = _transformationControllers[index]!.value
                  .getMaxScaleOnAxis();

              if (scale > 1.01) {
                if (_pagePhysics is! NeverScrollableScrollPhysics) {
                  setState(
                    () => _pagePhysics = const NeverScrollableScrollPhysics(),
                  );
                }
              } else {
                if (_pagePhysics is! BouncingScrollPhysics) {
                  setState(() => _pagePhysics = const BouncingScrollPhysics());
                }
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base Image
                Image.file(
                  state.imageFile!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.broken_image)),
                ),

                // Overlays (Only if NOT showing original)
                if (!_showOriginal && state.imageSize != null)
                  ...state.overlays.map((block) {
                    if (block.translatedText == null) return const SizedBox();

                    final imgWidth = state.imageSize!.width;
                    final imgHeight = state.imageSize!.height;

                    // Calculate fitted sizes to match BoxFit.contain
                    final double scaleW = constraints.maxWidth / imgWidth;
                    final double scaleH = constraints.maxHeight / imgHeight;
                    final double scale = scaleW < scaleH ? scaleW : scaleH;

                    final double renderedWidth = imgWidth * scale;
                    final double renderedHeight = imgHeight * scale;

                    final double dx =
                        (constraints.maxWidth - renderedWidth) / 2;
                    final double dy =
                        (constraints.maxHeight - renderedHeight) / 2;

                    return Positioned(
                      left: dx + (block.rect.left * scale),
                      top: dy + (block.rect.top * scale),
                      width: block.rect.width * scale,
                      height: block.rect.height * scale,
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.95),
                        padding: const EdgeInsets.all(1),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.topLeft,
                          child: Text(
                            block.translatedText!,
                            style: const TextStyle(
                              color: Colors.black,
                              fontFamily: 'Arial',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                if (state.isTranslating && !_showOriginal)
                  const Positioned(
                    top: 20,
                    right: 20,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TranslatedBlock {
  final String originalText;
  String? translatedText;
  final Rect rect;

  _TranslatedBlock({required this.originalText, required this.rect});
}
