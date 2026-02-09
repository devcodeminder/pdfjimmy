import 'package:pdfjimmy/services/offline_ai_service.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:ui'; // Needed for BackdropFilter

import 'package:pdfjimmy/services/dictionary.dart';
import 'package:pdfjimmy/services/translator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/pdf_controller.dart';
import '../utils/file_helper.dart';
import '../models/pdf_annotation_model.dart';
import '../models/drawing_model.dart';
import '../services/pdf_service.dart';
import '../services/action_history_manager.dart';
import '../services/auto_scroll_service.dart';
import '../services/pdf_tts_service.dart';
import '../widgets/drawing_overlay.dart';
import '../widgets/signature_overlay.dart';
import '../models/signature_placement_model.dart';
import '../models/signature_data.dart';
import '../screens/signature_library_screen.dart';
import '../screens/smart_search_screen.dart';
import '../widgets/tts_player_widget.dart';
import 'ai_translation_screen.dart';
import '../widgets/tts_highlight_overlay.dart';
import '../providers/signature_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf_lib;
import 'package:path_provider/path_provider.dart';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class EnhancedPdfViewerScreen extends StatefulWidget {
  final String filePath;
  final int initialPage;
  final String? password;

  const EnhancedPdfViewerScreen({
    Key? key,
    required this.filePath,
    this.initialPage = 0,
    this.password,
  }) : super(key: key);

  @override
  State<EnhancedPdfViewerScreen> createState() =>
      _EnhancedPdfViewerScreenState();
}

class _EnhancedPdfViewerScreenState extends State<EnhancedPdfViewerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Controllers
  late PdfViewerController _pdfViewerController;
  late AnimationController _toolbarAnimationController;
  late AnimationController _fabAnimationController;

  // UI State
  bool _showToolbar = true;
  bool _showSearch = false;
  bool _showThumbnails = false;
  bool _showBookmarks = false;
  bool _showNotes = false;
  bool _showHighlights = false;
  bool _isNightMode = false;
  bool _scrollLock = false;
  bool _isFabExpanded = false;
  bool _showTtsPlayer = false;
  bool _isDisposing = false;
  PdfFitMode _fitMode = PdfFitMode.fitWidth;
  PdfRotation _rotation = PdfRotation.rotate0;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.continuous;
  bool _enableDoubleTapZoom = true;
  bool _enableHaptics = true;
  bool _highContrastMode = false; // Accessibility State

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  PdfTextSearchResult? _searchResult;

  // Annotations
  List<TextHighlight> _highlights = [];
  List<PdfNote> _notes = [];

  // Drawing state
  DrawingMode _drawingMode = DrawingMode.none;
  Color _selectedDrawingColor = DrawingColors.black;
  double _selectedStrokeWidth = StrokeWidths.medium;
  List<DrawingPath> _drawings = [];

  // Signature state
  List<SignaturePlacement> _signaturePlacements = [];
  Map<String, SignatureData> _signaturesMap = {};
  int? _selectedSignaturePlacementId;
  bool _isExporting = false;

  // Advanced Services
  final ActionHistoryManager _historyManager = ActionHistoryManager();
  final AutoScrollService _autoScrollService = AutoScrollService();
  final PdfTtsService _ttsService = PdfTtsService();

  Color _ttsHighlightColor = Colors.greenAccent;
  List<Rect>? _currentTtsHighlightRects;
  Size _currentTtsPageSize = Size.zero;

  // Placement State

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();

    _toolbarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _toolbarAnimationController.forward();
    _fabAnimationController.forward();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<PdfController>();
      controller.setCurrentFile(widget.filePath);

      // Load last read page
      _loadLastReadPage();

      // Load annotations
      _loadAnnotations();

      // Load drawings
      _loadDrawings();

      // Load signatures
      _loadSignatures();

      // Navigate to initial page if specified
      // Methods for text actions like adding highlights/underlines are standard actions
      // that act on _selectedText. They can be triggered from other UI elements if needed.
    });
  }

  Future<void> _loadLastReadPage() async {
    final pdfFile = await PdfService.instance.getPdfFile(widget.filePath);
    if (pdfFile != null && pdfFile.lastPageRead > 0) {
      // Smart Resume: Jump and Notify
      _pdfViewerController.jumpToPage(pdfFile.lastPageRead + 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Resumed at page ${pdfFile.lastPageRead + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Start Over',
              textColor: Colors.white,
              onPressed: () {
                _pdfViewerController.jumpToPage(1);
                // Reset in DB handled by onPageChanged
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAnnotations() async {
    final highlights = await PdfService.instance.getHighlights(widget.filePath);
    final notes = await PdfService.instance.getNotes(widget.filePath);

    if (mounted) {
      setState(() {
        _highlights = highlights;
        _notes = notes;
      });
    }
  }

  Future<void> _loadDrawings() async {
    try {
      final drawings = await PdfService.instance.getDrawingsByFile(
        widget.filePath,
      );
      if (mounted && !_isDisposing) {
        setState(() {
          _drawings = drawings;
        });
      }
    } catch (e) {
      debugPrint('Error loading drawings: $e');
    }
  }

  Future<void> _loadSignatures() async {
    try {
      final placements = await PdfService.instance.getSignaturePlacementsByFile(
        widget.filePath,
      );

      // Load signature data for these placements
      if (mounted) {
        final provider = context.read<SignatureProvider>();
        // Ensure provider has loaded data
        if (provider.signatures.isEmpty) {
          await provider.loadStoredSignatures();
        }

        final Map<String, SignatureData> sigMap = {};
        final availableSigIds = provider.signatures.map((s) => s.id).toSet();

        for (var p in placements) {
          if (availableSigIds.contains(p.signatureId)) {
            sigMap[p.signatureId] = provider.signatures.firstWhere(
              (s) => s.id == p.signatureId,
            );
          }
        }

        if (!_isDisposing) {
          setState(() {
            _signaturePlacements = placements;
            _signaturesMap = sigMap;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading signatures: $e');
    }
  }

  Future<void> _addSignature(SignatureData signature) async {
    final controller = context.read<PdfController>();

    final placement = SignaturePlacement(
      filePath: widget.filePath,
      pageNumber: controller.currentPage,
      signatureId: signature.id,
      position: const Offset(100, 200),
      scale: 1.0,
      rotation: 0.0,
      createdAt: DateTime.now(),
    );

    final id = await PdfService.instance.saveSignaturePlacement(placement);
    final savedPlacement = placement.copyWith(id: id);

    _historyManager.addAction(
      HistoryAction(type: ActionType.addSignature, data: savedPlacement),
    );

    if (mounted && !_isDisposing) {
      setState(() {
        _signaturesMap[signature.id] = signature;
        _signaturePlacements.add(savedPlacement);
        _selectedSignaturePlacementId = id;
      });
    }
  }

  Future<void> _updateSignaturePlacement(SignaturePlacement placement) async {
    await PdfService.instance.updateSignaturePlacement(placement);
    if (mounted && !_isDisposing) {
      setState(() {
        final index = _signaturePlacements.indexWhere(
          (p) => p.id == placement.id,
        );
        if (index != -1) {
          _signaturePlacements[index] = placement;
        }
      });
    }
  }

  Future<void> _deleteSignaturePlacement(int id) async {
    // Find placement to save for undo
    try {
      final placement = _signaturePlacements.firstWhere((p) => p.id == id);
      _historyManager.addAction(
        HistoryAction(type: ActionType.removeSignature, data: placement),
      );
    } catch (_) {}

    await PdfService.instance.deleteSignaturePlacement(id);
    if (mounted && !_isDisposing) {
      setState(() {
        _signaturePlacements.removeWhere((p) => p.id == id);
        if (_selectedSignaturePlacementId != null) {
          _selectedSignaturePlacementId = null;
        }
      });
    }
  }

  Future<void> _exportSignedPdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final savedBytes = await _generateFlattenedPdf();

      // Write to temp file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${FileHelper.getFileName(widget.filePath)}_signed.pdf';
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(savedBytes);

      if (mounted) {
        Navigator.pop(context); // Close loading
        setState(() => _isExporting = false);
      }

      // Share
      await Share.shareXFiles([
        XFile(path),
      ], text: 'Here is my signed PDF document.');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _showAiSummaryDialog() async {
    setState(
      () => _isExporting = true,
    ); // Recycle exporting flag for loading state

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final service = OfflineAiService();
      final result = await service.analyzePdf(widget.filePath);

      if (mounted) {
        Navigator.pop(context); // Close loading
        setState(() => _isExporting = false);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.orange),
                SizedBox(width: 8),
                Text('AI Summary'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result['summary'] ?? 'No summary available.',
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const Divider(height: 30),
                  const Text(
                    'Stats:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Character Count: ${result['text_length']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: result['summary']));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Summary copied to clipboard'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navToSmartSearch() async {
    setState(() => _isExporting = true); // Loading state

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final service = OfflineAiService();
      // We need just the raw text now
      final text = await service.extractText(widget.filePath);

      if (mounted) {
        Navigator.pop(context); // Close loading
        setState(() => _isExporting = false);

        if (text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text could be extracted from this PDF.'),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmartSearchScreen(fullText: text),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _printPdf() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfBytes = await _generateFlattenedPdf();

      if (mounted) Navigator.pop(context); // hide loading

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => Uint8List.fromList(pdfBytes),
        name: FileHelper.getFileName(widget.filePath),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // hide loading just in case
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  Future<List<int>> _generateFlattenedPdf() async {
    // Load the original PDF document
    final List<int> bytes = await File(widget.filePath).readAsBytes();
    final pdf_lib.PdfDocument document = pdf_lib.PdfDocument(inputBytes: bytes);

    // Burn Annotations/Drawings/Signatures
    double accumulatedPageHeight = 0.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double zoomLevel = _pdfViewerController.zoomLevel;

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final pageSize = page.size; // Size in points

      // Calculate scale: Screen Width / PDF Page Width * Zoom
      final double renderScale = (screenWidth / pageSize.width) * zoomLevel;
      final double pageHeightInPixels = pageSize.height * renderScale;

      // 1. Burn Drawings (Best Effort)
      // Drawings are saved with Screen Coordinates (relative to viewport/page view).
      // Since DrawingOverlay resets on page change, we assume drawings are relative to the specific page view.
      // However, DrawingPath stores "localPosition" from GestureDetector which is Screen Coordinates.
      // We will assume the drawing was made when the page was fully visible or we use the relative position.
      // Given the limitations, we map screen pixels directly using renderScale.
      final pageDrawings = _drawings.where((d) => d.pageNumber == i).toList();

      for (final drawing in pageDrawings) {
        if (drawing.points.isEmpty) continue;

        // Convert DrawingPath points to PDF Path
        final pdfPath = pdf_lib.PdfPath();

        // Start point
        // X = point.dx / renderScale
        // Y = point.dy / renderScale (Assuming point.dy is relative to page top.
        // If point.dy includes header offset, we might need adjustments, but DrawingOverlay usually handles local coord).

        if (drawing.points.length > 1) {
          for (int k = 0; k < drawing.points.length - 1; k++) {
            final p1 = drawing.points[k];
            final p2 = drawing.points[k + 1];
            pdfPath.addLine(
              Offset(p1.dx / renderScale, p1.dy / renderScale),
              Offset(p2.dx / renderScale, p2.dy / renderScale),
            );
          }
        }

        final pdfPen = pdf_lib.PdfPen(
          pdf_lib.PdfColor(
            drawing.color.red,
            drawing.color.green,
            drawing.color.blue,
            255, // Alpha ignored or 255
          ),
          width: drawing.strokeWidth / renderScale,
        );

        page.graphics.drawPath(pdfPath, pen: pdfPen);
      }

      // 2. Burn Signatures
      final pageSignatures = _signaturePlacements
          .where((p) => p.pageNumber == i)
          .toList();

      for (final placement in pageSignatures) {
        final sigData = _signaturesMap[placement.signatureId];
        if (sigData != null) {
          final image = pdf_lib.PdfBitmap(sigData.imageData);

          page.graphics.save();

          // Transform coordinates
          // placement.position is in "Absolute Document View Pixels" (Screen Scale).
          // Page Start Y is accumulatedPageHeight.
          // Relative Y = placement.position.dy - accumulatedPageHeight.
          final double pdfX = placement.position.dx / renderScale;
          final double containerW = 160.0 * placement.scale;
          final double containerH = 80.0 * placement.scale;

          final double imageAspectRatio =
              image.width.toDouble() / image.height.toDouble();
          final double containerAspectRatio = containerW / containerH;

          double drawW;
          double drawH;

          if (imageAspectRatio > containerAspectRatio) {
            drawW = containerW;
            drawH = containerW / imageAspectRatio;
          } else {
            drawW = containerH * imageAspectRatio;
            drawH = containerH;
          }

          final double pdfDrawW = drawW / renderScale;
          final double pdfDrawH = drawH / renderScale;
          final double pdfContainerW = containerW / renderScale;
          final double pdfContainerH = containerH / renderScale;

          final double pdfOffsetX = (pdfContainerW - pdfDrawW) / 2;
          final double pdfOffsetY = (pdfContainerH - pdfDrawH) / 2;
          final double finalPdfX = pdfX + pdfOffsetX;

          // Re-calculating Y completely
          double targetY =
              (placement.position.dy - accumulatedPageHeight) / renderScale;

          // Add Centering:
          targetY += pdfOffsetY;

          // Apply User's Magic Calibration (Lift up)
          targetY = targetY - (pdfDrawH * 0.20) - (80.0 / renderScale);

          page.graphics.translateTransform(finalPdfX, targetY);
          page.graphics.rotateTransform(placement.rotation * 180 / 3.14159);

          page.graphics.drawImage(
            image,
            Rect.fromLTWH(0, 0, pdfDrawW, pdfDrawH),
          );

          page.graphics.restore();
        }
      }

      accumulatedPageHeight +=
          pageHeightInPixels + 5.0; // Inter-page spacing (Gap)
    }

    // Save the document
    final List<int> savedBytes = await document.save();
    document.dispose();
    return savedBytes;
  }

  @override
  void dispose() {
    // Set disposing flag first to prevent any callbacks from executing
    _isDisposing = true;

    // Stop TTS immediately
    _ttsService.stop();

    _searchResult = null;

    _searchController.dispose();
    _searchFocusNode.dispose();

    // Dispose PDF viewer controller last
    _pdfViewerController.dispose();
    _toolbarAnimationController.dispose();
    _fabAnimationController.dispose();
    _autoScrollService.dispose();
    _ttsService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Crash Recovery: Save state aggressively on pause/inactive
      final controller = context.read<PdfController>();
      if (controller.isReady) {
        PdfService.instance.updateLastPage(
          widget.filePath,
          controller.currentPage,
        );
      }
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    PaintingBinding.instance.imageCache.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Low memory detected. Clearing cache to free RAM.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
      if (_showToolbar) {
        _toolbarAnimationController.forward();
      } else {
        _toolbarAnimationController.reverse();
      }
      if (_enableHaptics) HapticFeedback.selectionClick();
    });
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
  }

  void _rotatePdf() {
    setState(() {
      _rotation = _rotation.next;
    });
  }

  void _performSearch(String searchText) {
    if (searchText.isEmpty) {
      _clearSearch();
      return;
    }

    _searchResult?.clear();
    _searchResult = _pdfViewerController.searchText(searchText);

    if (_searchResult != null) {
      _searchResult!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _clearSearch() {
    _searchResult?.clear();
    _searchResult = null;
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleAutoScroll(PdfController controller) {
    if (_autoScrollService.isScrolling) {
      _autoScrollService.stopAutoScroll();
    } else {
      _autoScrollService.startAutoScroll(
        _pdfViewerController,
        controller.totalPages,
      );
    }
    setState(() {});
  }

  void _undo() async {
    final action = _historyManager.undo();
    if (action == null) return;

    switch (action.type) {
      case ActionType.addDrawing:
        if (action.data is DrawingPath) {
          final d = action.data as DrawingPath;
          if (d.id != null) {
            await PdfService.instance.deleteDrawing(d.id!);
            _loadDrawings();
          }
        }
        break;
      case ActionType.removeDrawing:
        if (action.data is DrawingPath) {
          final newId = await PdfService.instance.saveDrawing(
            action.data as DrawingPath,
          );
          action.data = (action.data as DrawingPath).copyWith(id: newId);
          _loadDrawings();
        }
        break;
      case ActionType.addSignature:
        if (action.data is SignaturePlacement) {
          final s = action.data as SignaturePlacement;
          if (s.id != null) {
            await PdfService.instance.deleteSignaturePlacement(s.id!);
            _loadSignatures();
          }
        }
        break;
      case ActionType.removeSignature:
        if (action.data is SignaturePlacement) {
          final newId = await PdfService.instance.saveSignaturePlacement(
            action.data as SignaturePlacement,
          );
          action.data = (action.data as SignaturePlacement).copyWith(id: newId);
          _loadSignatures();
        }
        break;
      case ActionType.addHighlight:
        if (action.data is TextHighlight) {
          final h = action.data as TextHighlight;
          if (h.id != null) {
            await PdfService.instance.deleteHighlight(h.id!);
            _loadAnnotations();
          }
        }
        break;
      case ActionType.removeHighlight:
        if (action.data is TextHighlight) {
          final newId = await PdfService.instance.createHighlight(
            action.data as TextHighlight,
          );
          action.data = (action.data as TextHighlight).copyWith(id: newId);
          _loadAnnotations();
        }
        break;
      case ActionType.addNote:
        if (action.data is PdfNote) {
          final n = action.data as PdfNote;
          if (n.id != null) {
            await PdfService.instance.deleteNote(n.id!);
            _loadAnnotations();
          }
        }
        break;
      case ActionType.removeNote:
        if (action.data is PdfNote) {
          final newId = await PdfService.instance.createNote(
            action.data as PdfNote,
          );
          action.data = (action.data as PdfNote).copyWith(id: newId);
          _loadAnnotations();
        }
        break;
      default:
        break;
    }
    setState(() {});
  }

  void _redo() async {
    final action = _historyManager.redo();
    if (action == null) return;

    switch (action.type) {
      case ActionType.addDrawing:
        if (action.data is DrawingPath) {
          final newId = await PdfService.instance.saveDrawing(
            action.data as DrawingPath,
          );
          action.data = (action.data as DrawingPath).copyWith(id: newId);
          _loadDrawings();
        }
        break;
      case ActionType.removeDrawing:
        if (action.data is DrawingPath) {
          final d = action.data as DrawingPath;
          if (d.id != null) {
            await PdfService.instance.deleteDrawing(d.id!);
            _loadDrawings();
          }
        }
        break;
      case ActionType.addSignature:
        if (action.data is SignaturePlacement) {
          final newId = await PdfService.instance.saveSignaturePlacement(
            action.data as SignaturePlacement,
          );
          action.data = (action.data as SignaturePlacement).copyWith(id: newId);
          _loadSignatures();
        }
        break;
      case ActionType.removeSignature:
        if (action.data is SignaturePlacement) {
          final s = action.data as SignaturePlacement;
          if (s.id != null) {
            await PdfService.instance.deleteSignaturePlacement(s.id!);
            _loadSignatures();
          }
        }
        break;
      case ActionType.addHighlight:
        if (action.data is TextHighlight) {
          final newId = await PdfService.instance.createHighlight(
            action.data as TextHighlight,
          );
          action.data = (action.data as TextHighlight).copyWith(id: newId);
          _loadAnnotations();
        }
        break;
      case ActionType.removeHighlight:
        if (action.data is TextHighlight) {
          final h = action.data as TextHighlight;
          if (h.id != null) {
            await PdfService.instance.deleteHighlight(h.id!);
            _loadAnnotations();
          }
        }
        break;
      case ActionType.addNote:
        if (action.data is PdfNote) {
          final newId = await PdfService.instance.createNote(
            action.data as PdfNote,
          );
          action.data = (action.data as PdfNote).copyWith(id: newId);
          _loadAnnotations();
        }
        break;
      case ActionType.removeNote:
        if (action.data is PdfNote) {
          final n = action.data as PdfNote;
          if (n.id != null) {
            await PdfService.instance.deleteNote(n.id!);
            _loadAnnotations();
          }
        }
        break;
      default:
        break;
    }
    setState(() {});
  }

  // Text Selection Menu removed as per request.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: GestureDetector(
        onTap: _toggleToolbar,
        child: Stack(
          children: [
            // PDF Viewer (Full Screen)
            // Optimized: Moved outside Consumer to prevent rebuilds on page change
            Positioned.fill(
              child: Container(
                color: _isNightMode
                    ? Colors.grey[900]
                    : (_highContrastMode ? Colors.black : Colors.white),
                child: _buildPdfViewer(context.read<PdfController>()),
              ),
            ),

            // Overlays that require controller state
            Consumer<PdfController>(
              builder: (context, controller, child) {
                return Stack(
                  children: [
                    // Drawing Overlay (above PDF, below toolbars)
                    if (_drawingMode != DrawingMode.none && controller.isReady)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 60, // Space for app bar
                            bottom: 80, // Space for bottom toolbar
                          ),
                          child: DrawingOverlay(
                            pageNumber: controller.currentPage,
                            existingDrawings: _drawings,
                            selectedColor: _selectedDrawingColor,
                            strokeWidth: _selectedStrokeWidth,
                            drawingMode: _drawingMode,
                            filePath: widget.filePath,
                            onDrawingComplete: (drawing) async {
                              final id = await PdfService.instance.saveDrawing(
                                drawing,
                              );
                              final savedDrawing = drawing.copyWith(id: id);
                              _historyManager.addAction(
                                HistoryAction(
                                  type: ActionType.addDrawing,
                                  data: savedDrawing,
                                ),
                              );
                              if (mounted && !_isDisposing) {
                                setState(() {
                                  _drawings.add(savedDrawing);
                                });
                              }
                            },
                            onDrawingErased: (drawingId) async {
                              final drawing = _drawings.firstWhere(
                                (d) => d.id == drawingId,
                                orElse: () => DrawingPath(
                                  filePath: widget.filePath,
                                  pageNumber: controller.currentPage,
                                  points: [],
                                  color: Colors.black,
                                  strokeWidth: 1.0,
                                ),
                              );

                              if (drawing.points.isNotEmpty) {
                                _historyManager.addAction(
                                  HistoryAction(
                                    type: ActionType.removeDrawing,
                                    data: drawing,
                                  ),
                                );
                              }

                              await PdfService.instance.deleteDrawing(
                                drawingId,
                              );
                              if (mounted && !_isDisposing) {
                                setState(() {
                                  _drawings.removeWhere(
                                    (d) => d.id == drawingId,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ),

                    // Signature Overlay (Always visible if signatures exist)
                    if (controller.isReady)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60, bottom: 80),
                          child: SignatureOverlay(
                            pageNumber: controller.currentPage,
                            placements: _signaturePlacements,
                            signaturesMap: _signaturesMap,
                            selectedPlacementId: _selectedSignaturePlacementId,
                            scrollOffset: _pdfViewerController.scrollOffset.dy,
                            onSignatureSelected: (placementId) {
                              setState(
                                () =>
                                    _selectedSignaturePlacementId = placementId,
                              );
                            },
                            onPlacementUpdate: (placement) =>
                                _updateSignaturePlacement(placement),
                            onPlacementDelete: (id) =>
                                _deleteSignaturePlacement(id),
                            onConfirmSelection: () {
                              setState(
                                () => _selectedSignaturePlacementId = null,
                              );
                            },
                          ),
                        ),
                      ),

                    if (!controller.isReady) _buildLoadingIndicator(),

                    // Error Message
                    if (controller.errorMessage.isNotEmpty)
                      _buildErrorMessage(controller),

                    // Top Toolbar
                    if (_showToolbar) _buildTopToolbar(controller),

                    // Search Bar
                    if (_showSearch) _buildSearchBar(),

                    // Bottom Toolbar
                    if (_showToolbar) _buildBottomToolbar(controller),

                    // Thumbnails Sidebar
                    if (_showThumbnails) _buildThumbnailsSidebar(controller),

                    // Bookmarks Sidebar
                    if (_showBookmarks) _buildBookmarksSidebar(controller),

                    // Notes Sidebar
                    if (_showNotes) _buildNotesSidebar(controller),

                    // Highlights Sidebar
                    if (_showHighlights) _buildHighlightsSidebar(controller),

                    // Drawing Toolbar - Show only when drawing mode is active
                    if (_drawingMode != DrawingMode.none)
                      _buildDrawingToolbar(),

                    // TTS Player Overlay
                    if (_showTtsPlayer)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: TtsPlayerWidget(
                          filePath: widget.filePath,
                          currentPage: controller.currentPage,
                          onPageChanged: (page) =>
                              _pdfViewerController.jumpToPage(page + 1),
                          onClose: () {
                            setState(() => _showTtsPlayer = false);
                            _pdfViewerController.clearSelection();
                            _searchResult?.clear();
                          },
                          onWordSpoken:
                              (word, start, end, allText, rects, pageSize) {
                                if (!mounted) return;
                                setState(() {
                                  _currentTtsHighlightRects = rects;
                                  _currentTtsPageSize = pageSize;
                                  // Ensure high contrast or visibility if needed
                                });
                              },
                          currentHighlightColor: _ttsHighlightColor,
                          onHighlightColorChanged: (color) {
                            setState(() => _ttsHighlightColor = color);
                          },
                          ttsService: _ttsService,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: (_showToolbar && !_showTtsPlayer)
          ? _buildFloatingActionButtons()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildPdfViewer(PdfController controller) {
    return SafeArea(
      child: Container(
        color: _isNightMode
            ? Colors.grey[850]
            : (_highContrastMode ? Colors.black : Colors.white),
        child: Transform.rotate(
          angle: _rotation.degrees * 3.14159 / 180,
          child: ColorFiltered(
            colorFilter: _isNightMode
                ? const ColorFilter.mode(Colors.black54, BlendMode.darken)
                : (_highContrastMode
                      ? const ColorFilter.mode(
                          Colors.white,
                          BlendMode.difference,
                        ) // High Contrast Invert
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        )),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Rebuild to update signature positions when scrolling
                if (notification is ScrollUpdateNotification) {
                  if (mounted && !_isDisposing) {
                    setState(() {});
                  }
                }
                return true;
              },
              child: AbsorbPointer(
                absorbing: _scrollLock,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 60, // Space for app bar
                    bottom: 80, // Space for bottom toolbar
                  ),
                  child: Stack(
                    children: [
                      SfPdfViewer.file(
                        File(widget.filePath),
                        key: ValueKey(
                          widget.filePath,
                        ), // Orientation change without reload
                        password: widget.password,
                        controller: _pdfViewerController,
                        enableDoubleTapZooming:
                            !_scrollLock &&
                            _enableDoubleTapZoom, // Gesture Customization
                        enableTextSelection: !_scrollLock,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        canShowPaginationDialog: !_scrollLock,
                        initialScrollOffset: Offset.zero,
                        initialZoomLevel: _fitMode == PdfFitMode.fitWidth
                            ? 1.0
                            : 1.0,
                        interactionMode: _scrollLock
                            ? PdfInteractionMode.pan
                            : PdfInteractionMode.selection,
                        scrollDirection: PdfScrollDirection.vertical,
                        pageLayoutMode: _pageLayoutMode,
                        // Dynamic Highlight Colors for TTS vs Search
                        currentSearchTextHighlightColor: _showTtsPlayer
                            ? _ttsHighlightColor.withOpacity(
                                0.6,
                              ) // User-selected TTS Color
                            : Colors.orangeAccent.withOpacity(
                                0.5,
                              ), // Search Color
                        otherSearchTextHighlightColor: _showTtsPlayer
                            ? Colors
                                  .transparent // Hide others during reading
                            : Colors.yellow.withOpacity(
                                0.3,
                              ), // Show others during search
                        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                          if (mounted && !_isDisposing) {
                            controller.setTotalPages(
                              details.document.pages.count,
                            );
                            controller.setReady(true);
                            controller.savePdfFile(
                              widget.filePath,
                              details.document.pages.count,
                            );
                          }
                        },
                        onDocumentLoadFailed:
                            (PdfDocumentLoadFailedDetails details) {
                              if (mounted && !_isDisposing) {
                                controller.setErrorMessage(details.error);
                              }
                            },
                        onPageChanged: (PdfPageChangedDetails details) {
                          if (mounted && !_isDisposing) {
                            if (_enableHaptics)
                              HapticFeedback.selectionClick(); // Haptics
                            controller.setCurrentPage(
                              details.newPageNumber - 1,
                            );
                          }
                        },
                        onTextSelectionChanged:
                            (PdfTextSelectionChangedDetails details) {},
                      ),
                      if (_showTtsPlayer &&
                          _currentTtsHighlightRects != null &&
                          _currentTtsPageSize != Size.zero)
                        Positioned.fill(
                          child: TtsHighlightOverlay(
                            highlightRects: _currentTtsHighlightRects!,
                            pageSize: _currentTtsPageSize,
                            pageIndex: controller.currentPage,
                            scrollOffset: _pdfViewerController.scrollOffset.dy,
                            zoomLevel: _pdfViewerController.zoomLevel,
                            highlightColor: _ttsHighlightColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: _isNightMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom Icon Container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.description_outlined,
                  size: 40,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Premium Text
            Text(
              'Preparing Document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _isNightMode ? Colors.white : Colors.black87,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Custom Linear Progress bar (Pill shaped)
            SizedBox(
              width: 200,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFFEEEEEE),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait...',
              style: TextStyle(
                fontSize: 12,
                color: _isNightMode ? Colors.white54 : Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(PdfController controller) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error Loading PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                controller.errorMessage,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayName(String path) {
    final name = FileHelper.getFileName(path);
    if (name.length > 25) {
      return '${name.substring(0, 12)}...${name.substring(name.length - 8)}';
    }
    return name;
  }

  Widget _buildTopToolbar(PdfController controller) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _toolbarAnimationController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent, // Removed heavy background
          ),
          child: Row(
            children: [
              // Game Style Back Button
              _buildGameStyleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                color: Colors.cyan,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'filename_${widget.filePath}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          _getDisplayName(widget.filePath),
                          style: TextStyle(
                            color: _isNightMode
                                ? Colors.white
                                : const Color(0xFF2D3436),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: _isNightMode
                                    ? Colors.black
                                    : Colors.white,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Text(
                      '${controller.currentPage + 1} / ${controller.totalPages}',
                      style: TextStyle(
                        color: _isNightMode ? Colors.white70 : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: _isNightMode ? Colors.black : Colors.white,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Game Style Search Button
              _buildGameStyleButton(
                icon: Icons.search_rounded,
                color: Colors.purpleAccent,
                onTap: () {
                  setState(() => _showSearch = !_showSearch);
                  if (_showSearch) {
                    _searchFocusNode.requestFocus();
                  } else {
                    _searchController.clear();
                    _clearSearch();
                    _searchFocusNode.unfocus();
                  }
                },
              ),
              const SizedBox(width: 12),
              // Game Style Menu Button
              _buildGameStyleButton(
                icon: Icons.more_vert_rounded,
                color: Colors.deepOrange,
                onTap: () => _showGameStyleMenu(context, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameStyleMenu(BuildContext context, PdfController controller) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Game Menu',
      barrierColor: Colors.black.withOpacity(0.8), // Dark overlay
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Slate 800
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.deepOrange, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepOrange.withOpacity(0.5),
                        ),
                      ),
                      child: const Text(
                        'MENU',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Grid Options
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildGameMenuButton(
                          icon: Icons.grid_view_rounded,
                          label: 'Pages',
                          color: Colors.pink,
                          onTap: () => setState(
                            () => _showThumbnails = !_showThumbnails,
                          ),
                        ),
                        _buildGameMenuButton(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Bookmarks',
                          color: Colors.blue,
                          onTap: () =>
                              setState(() => _showBookmarks = !_showBookmarks),
                        ),
                        _buildGameMenuButton(
                          icon: Icons.note_alt_outlined,
                          label: 'Notes',
                          color: Colors.purple,
                          onTap: () => setState(() => _showNotes = !_showNotes),
                        ),
                        _buildGameMenuButton(
                          icon: Icons.record_voice_over_rounded,
                          label: 'Read',
                          color: Colors.teal,
                          onTap: () =>
                              setState(() => _showTtsPlayer = !_showTtsPlayer),
                        ),
                        _buildGameMenuButton(
                          icon: _isNightMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          label: 'Theme',
                          color: Colors.indigo,
                          onTap: _toggleNightMode,
                        ),
                        _buildGameMenuButton(
                          icon: Icons.rotate_right_rounded,
                          label: 'Rotate',
                          color: Colors.amber,
                          onTap: _rotatePdf,
                        ),
                        _buildGameMenuButton(
                          icon: _scrollLock
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          label: _scrollLock ? 'Unlock' : 'Lock',
                          color: Colors.redAccent,
                          onTap: () =>
                              setState(() => _scrollLock = !_scrollLock),
                        ),
                        _buildGameMenuButton(
                          icon: _autoScrollService.isScrolling
                              ? Icons.stop_circle_outlined
                              : Icons.slideshow_rounded,
                          label: _autoScrollService.isScrolling
                              ? 'Stop Scroll'
                              : 'Auto Scroll',
                          color: Colors.amberAccent.shade700,
                          onTap: () => _toggleAutoScroll(controller),
                        ),
                        _buildGameMenuButton(
                          icon: Icons.translate_rounded,
                          label: 'Translate',
                          color: Colors.lightGreen,
                          onTap: () {
                            if (controller.currentFilePath != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AITranslationScreen(
                                    filePath: widget.filePath,
                                    fileName: FileHelper.getFileName(
                                      widget.filePath,
                                    ),
                                    initialPage: controller.currentPage,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        _buildGameMenuButton(
                          icon: Icons.accessibility_new_rounded,
                          label: 'Access',
                          color: Colors.deepPurpleAccent,
                          onTap: _showAccessibilityDialog,
                        ),
                        _buildGameMenuButton(
                          icon: Icons.print_rounded,
                          label: 'Print',
                          color: Colors.orange,
                          onTap: _printPdf,
                        ),
                        _buildGameMenuButton(
                          icon: Icons.save_as_rounded,
                          label: 'Export',
                          color: Colors.cyan,
                          onTap: _exportSignedPdf,
                        ),
                        _buildGameMenuButton(
                          icon: Icons.info_outline_rounded,
                          label: 'Info',
                          color: Colors.blueGrey,
                          onTap: () => _showDocumentInfo(controller),
                        ),
                        _buildGameMenuButton(
                          icon: Icons.touch_app_rounded,
                          label: 'Gestures',
                          color: Colors.brown,
                          onTap: _showGestureSettingsDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 2,
                            ),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'CLOSE MENU',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (_enableHaptics) HapticFeedback.selectionClick();
        Navigator.pop(context); // Close menu first
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGameStyleButton(
            icon: icon,
            color: color,
            size: 60,
            iconSize: 28,
            onTap: null, // Tap handled by outer gesture detector
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStyleButton({
    required IconData icon,
    required Color color,
    double size = 44,
    double iconSize = 24,
    VoidCallback? onTap,
  }) {
    // Determine colors using HSL for safe shifting
    final hsl = HSLColor.fromColor(color);
    final colorLight = hsl
        .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();
    final colorDark = hsl
        .withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0))
        .toColor();
    final colorShadow = hsl
        .withLightness((hsl.lightness - 0.3).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onTap: onTap != null
          ? () {
              if (_enableHaptics) HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorLight, colorDark],
          ),
          borderRadius: BorderRadius.circular(
            size * 0.32,
          ), // Proportional radius
          boxShadow: [
            // 3D Depth Shadow
            BoxShadow(
              color: colorShadow,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
            // Soft Glow
            BoxShadow(
              color: color.withOpacity(0.4),
              offset: const Offset(0, 8),
              blurRadius: 10,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0.25), Colors.transparent],
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
            shadows: const [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGestureSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Gestures & Haptics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Double Tap to Zoom'),
                  value: _enableDoubleTapZoom,
                  onChanged: (value) {
                    setState(() => _enableDoubleTapZoom = value);
                    this.setState(() {}); // Update parent state
                  },
                ),
                SwitchListTile(
                  title: const Text('Haptic Feedback (Vibration)'),
                  value: _enableHaptics,
                  onChanged: (value) {
                    setState(() => _enableHaptics = value);
                    this.setState(() {}); // Update parent state
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Accessibility'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('High Contrast Mode'),
                  subtitle: const Text(
                    'Increases text legibility and contrast.',
                  ),
                  value: _highContrastMode,
                  onChanged: (value) {
                    setState(() => _highContrastMode = value);
                    this.setState(() {}); // Update parent
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 56,
      left: 10,
      right: 10,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search text...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixText: _searchResult != null
                        ? '${_searchResult!.currentInstanceIndex + 1}/${_searchResult!.totalInstanceCount}'
                        : null,
                  ),
                  onChanged: (value) => _performSearch(value),
                  onSubmitted: (value) => _performSearch(value),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: _searchResult != null
                    ? () => _searchResult!.previousInstance()
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: _searchResult != null
                    ? () => _searchResult!.nextInstance()
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _showSearch = false);
                  _searchController.clear();
                  _clearSearch();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(PdfController controller) {
    return Positioned(
      bottom: 24,
      left: 32,
      right: 32,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _toolbarAnimationController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: Container(
          // Clean Glass Design without "s . s . s" artifacts
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isNightMode
                ? const Color(0xFF2C2C2C).withOpacity(0.9)
                : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              // Gentle Glow instead of heavy shadow
              BoxShadow(
                color: _isNightMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBottomBarIcon(
                  icon: Icons.auto_awesome,
                  color: Colors.orange,
                  onTap: _showAiSummaryDialog,
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.withOpacity(0.2),
                ),
                _buildBottomBarIcon(
                  icon: Icons.manage_search_rounded,
                  color: Colors.indigoAccent,
                  onTap: _navToSmartSearch,
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.withOpacity(0.2),
                ),
                _buildBottomBarIcon(
                  icon: Icons.translate_rounded,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AITranslationScreen(
                          filePath: widget.filePath,
                          fileName: FileHelper.getFileName(widget.filePath),
                          initialPage: _pdfViewerController.pageNumber,
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.withOpacity(0.2),
                ),
                _buildBottomBarIcon(
                  icon: _fitMode == PdfFitMode.fitWidth
                      ? Icons.fit_screen_rounded
                      : Icons.fullscreen_exit_rounded,
                  color: Colors.orange.shade700,
                  onTap: () {
                    setState(() {
                      _fitMode = _fitMode == PdfFitMode.fitWidth
                          ? PdfFitMode.fitPage
                          : PdfFitMode.fitWidth;
                    });
                    _pdfViewerController.zoomLevel = 1.0;
                  },
                ),
                _buildBottomBarIcon(
                  icon: controller.isBookmarked(controller.currentPage)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: controller.isBookmarked(controller.currentPage)
                      ? Colors.orange.shade700
                      : (_isNightMode ? Colors.white : Colors.black54),
                  onTap: () {
                    if (_enableHaptics) HapticFeedback.selectionClick();
                    _toggleBookmark(controller);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color:
                color ??
                (_isNightMode ? Colors.white : const Color(0xFF555555)),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContainer({
    required String title,
    required VoidCallback onClose,
    required Widget child,
    double width = 300,
  }) {
    return Positioned(
      right: 16, // Float from right
      top: 100,
      bottom: 100,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: _isNightMode ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(-5, 5),
              ),
            ],
            border: Border.all(
              color: _isNightMode
                  ? Colors.white10
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  decoration: BoxDecoration(
                    color: _isNightMode
                        ? Colors.black26
                        : const Color(0xFFFAFAFA),
                    border: Border(
                      bottom: BorderSide(
                        color: _isNightMode
                            ? Colors.white10
                            : Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isNightMode
                                ? Colors.white
                                : const Color(0xFF2D3436),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isNightMode
                                ? Colors.white10
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _isNightMode
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailsSidebar(PdfController controller) {
    return _buildSidebarContainer(
      title: 'Pages',
      width: 180,
      onClose: () => setState(() => _showThumbnails = false),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: controller.totalPages,
        itemBuilder: (context, index) {
          final isSelected = controller.currentPage == index;
          return GestureDetector(
            onTap: () {
              _pdfViewerController.jumpToPage(index + 1);
              setState(() => _showThumbnails = false);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Colors.orange.shade700, width: 2)
                    : Border.all(
                        color: _isNightMode
                            ? Colors.white10
                            : Colors.grey.shade200,
                      ),
                color: _isNightMode ? Colors.black12 : Colors.white,
              ),
              child: Column(
                children: [
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: _isNightMode
                          ? Colors.white10
                          : Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 40,
                        color: isSelected
                            ? Colors.orange.shade700
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Page ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _isNightMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookmarksSidebar(PdfController controller) {
    return _buildSidebarContainer(
      title: 'Bookmarks',
      onClose: () => setState(() => _showBookmarks = false),
      child: controller.bookmarks.isEmpty
          ? _buildEmptyState('No bookmarks yet', Icons.bookmark_border_rounded)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: controller.bookmarks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bookmark = controller.bookmarks[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.bookmark_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    bookmark.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: _isNightMode
                          ? Colors.white
                          : const Color(0xFF2D3436),
                    ),
                  ),
                  subtitle: Text(
                    'Page ${bookmark.pageNumber + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isNightMode ? Colors.white54 : Colors.grey[500],
                    ),
                  ),
                  onTap: () {
                    _pdfViewerController.jumpToPage(bookmark.pageNumber + 1);
                    setState(() => _showBookmarks = false);
                  },
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                    onPressed: () => controller.removeBookmark(bookmark.id!),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: _isNightMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _isNightMode ? Colors.white54 : Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSidebar(PdfController controller) {
    return _buildSidebarContainer(
      title: 'Notes',
      onClose: () => setState(() => _showNotes = false),
      child: _notes.isEmpty
          ? _buildEmptyState('No notes yet', Icons.note_alt_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isNightMode ? Colors.white10 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isNightMode
                          ? Colors.transparent
                          : Colors.grey.shade200,
                    ),
                    boxShadow: _isNightMode
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: InkWell(
                    onTap: () {
                      _pdfViewerController.jumpToPage(note.pageNumber + 1);
                      setState(() => _showNotes = false);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Page ${note.pageNumber + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _editNote(note),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                _historyManager.addAction(
                                  HistoryAction(
                                    type: ActionType.removeNote,
                                    data: note,
                                  ),
                                );
                                await PdfService.instance.deleteNote(note.id!);
                                await _loadAnnotations();
                              },
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: Colors.red[300],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          note.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _isNightMode
                                ? Colors.white
                                : const Color(0xFF2D3436),
                          ),
                        ),
                        if (note.content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            note.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: _isNightMode
                                  ? Colors.white60
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHighlightsSidebar(PdfController controller) {
    return _buildSidebarContainer(
      title: 'Highlights',
      onClose: () => setState(() => _showHighlights = false),
      child: _highlights.isEmpty
          ? _buildEmptyState('No highlights yet', Icons.format_paint_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _highlights.length,
              itemBuilder: (context, index) {
                final highlight = _highlights[index];
                return Dismissible(
                  key: Key(highlight.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: Colors.red[100],
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red[700],
                    ),
                  ),
                  onDismissed: (direction) async {
                    _historyManager.addAction(
                      HistoryAction(
                        type: ActionType.removeHighlight,
                        data: highlight,
                      ),
                    );
                    await PdfService.instance.deleteHighlight(highlight.id!);
                    await _loadAnnotations();
                  },
                  child: InkWell(
                    onTap: () {
                      _pdfViewerController.jumpToPage(highlight.pageNumber + 1);
                      setState(() => _showHighlights = false);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isNightMode ? Colors.white10 : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(color: highlight.color, width: 4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            highlight.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: _isNightMode
                                  ? Colors.white70
                                  : const Color(0xFF2D3436),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Page ${highlight.pageNumber + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _isNightMode
                                  ? Colors.white38
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 90, right: 4),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isFabExpanded) ...[
              _buildGameFabItem(
                Icons.record_voice_over_rounded,
                'AI READER',
                () {
                  setState(() {
                    _showTtsPlayer = !_showTtsPlayer;
                    _isFabExpanded = false;
                  });
                },
                color: Colors.amberAccent,
              ),
              _buildGameFabItem(Icons.grid_view_rounded, 'THUMBNAILS', () {
                setState(() {
                  _showThumbnails = !_showThumbnails;
                  _isFabExpanded = false;
                });
              }, color: Colors.pinkAccent),
              _buildGameFabItem(
                _drawingMode == DrawingMode.none
                    ? Icons.edit_rounded
                    : Icons.edit_off_rounded,
                _drawingMode == DrawingMode.none ? 'DRAW' : 'STOP DRAW',
                () {
                  setState(() {
                    _drawingMode = _drawingMode == DrawingMode.none
                        ? DrawingMode.draw
                        : DrawingMode.none;
                    _isFabExpanded = false;
                  });
                },
                color: Colors.purpleAccent,
              ),
              _buildGameFabItem(Icons.bookmark_rounded, 'BOOKMARKS', () {
                setState(() {
                  _showBookmarks = !_showBookmarks;
                  _isFabExpanded = false;
                });
              }, color: Colors.blueAccent),
              _buildGameFabItem(Icons.note_alt_rounded, 'NOTES', () {
                setState(() {
                  _showNotes = !_showNotes;
                  _isFabExpanded = false;
                });
              }, color: Colors.cyanAccent),
              _buildGameFabItem(Icons.translate_rounded, 'TRANSLATE', () {
                setState(() => _isFabExpanded = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TranslatorScreen(initialText: ''),
                  ),
                );
              }, color: Colors.greenAccent),
              _buildGameFabItem(Icons.menu_book_rounded, 'DICTIONARY', () {
                setState(() => _isFabExpanded = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                );
              }, color: Colors.tealAccent),
              _buildGameFabItem(Icons.draw_rounded, 'SIGN', () {
                setState(() => _isFabExpanded = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignatureLibraryScreen(
                      onSelect: (signature) => _addSignature(signature),
                    ),
                  ),
                );
              }, color: Colors.deepOrangeAccent),
              const SizedBox(height: 16),
            ],

            // MAIN "GAMEPAD" BUTTON
            GestureDetector(
              onTap: () {
                if (_enableHaptics) HapticFeedback.mediumImpact();
                setState(() => _isFabExpanded = !_isFabExpanded);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade700,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    const BoxShadow(
                      color: Colors.white38,
                      blurRadius: 10,
                      offset: Offset(-4, -4), // Highlight
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(4, 4), // Shadow
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: AnimatedRotation(
                    turns: _isFabExpanded ? 0.375 : 0, // 135 degrees
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 32,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameFabItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Retro Label Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: color,
                letterSpacing: 1.2,
                fontFamily:
                    'Courier', // Monospace font for retro feel if available, else fallback
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Arcade Button
          GestureDetector(
            onTap: () {
              if (_enableHaptics) HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.8), color],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                  const BoxShadow(
                    color: Colors.white38,
                    blurRadius: 5,
                    offset: Offset(-2, -2), // Highlight
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBookmark(PdfController controller) {
    if (controller.isBookmarked(controller.currentPage)) {
      final bookmark = controller.getBookmarkForPage(controller.currentPage);
      if (bookmark != null) {
        controller.removeBookmark(bookmark.id!);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bookmark removed')));
      }
    } else {
      _showAddBookmarkDialog(controller);
    }
  }

  void _showAddBookmarkDialog(PdfController controller) {
    final titleController = TextEditingController(
      text: 'Page ${controller.currentPage + 1}',
    );
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.addBookmark(
                titleController.text.trim(),
                note: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Bookmark added')));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editNote(PdfNote note) {
    final titleController = TextEditingController(text: note.title);
    final contentController = TextEditingController(text: note.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedNote = note.copyWith(
                title: titleController.text,
                content: contentController.text,
                updatedAt: DateTime.now(),
              );
              await PdfService.instance.updateNote(updatedNote);
              await _loadAnnotations();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Note updated')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDocumentInfo(PdfController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('File', FileHelper.getFileName(widget.filePath)),
            _buildInfoRow('Current Page', '${controller.currentPage + 1}'),
            _buildInfoRow('Total Pages', '${controller.totalPages}'),
            _buildInfoRow(
              'Zoom Level',
              '${(_pdfViewerController.zoomLevel * 100).toStringAsFixed(0)}%',
            ),
            _buildInfoRow('Bookmarks', '${controller.bookmarks.length}'),
            _buildInfoRow('Notes', '${_notes.length}'),
            _buildInfoRow('Highlights', '${_highlights.length}'),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: FileHelper.getFileSize(widget.filePath),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildInfoRow(
                    'File Size',
                    FileHelper.formatFileSize(snapshot.data!),
                  );
                }
                return const Text('File Size: Loading...');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingToolbar() {
    return Positioned(
      top: 120,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - 280,
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drawing mode toggle/close
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close Tools',
                    onPressed: () {
                      setState(() {
                        _drawingMode = DrawingMode.none;
                      });
                    },
                  ),
                  const Divider(),

                  // Drawing mode toggle
                  IconButton(
                    icon: Icon(
                      _drawingMode == DrawingMode.draw
                          ? Icons.edit
                          : Icons.edit_outlined,
                      color: _drawingMode == DrawingMode.draw
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    tooltip: 'Draw',
                    onPressed: () {
                      setState(() {
                        _drawingMode = DrawingMode.draw;
                      });
                    },
                  ),

                  IconButton(
                    icon: Icon(
                      Icons.auto_fix_high,
                      color: _drawingMode == DrawingMode.erase
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    tooltip: 'Eraser',
                    onPressed: () {
                      setState(() {
                        _drawingMode = DrawingMode.erase;
                      });
                    },
                  ),

                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.undo,
                          color: _historyManager.canUndo
                              ? Colors.black87
                              : Colors.grey,
                        ),
                        onPressed: _historyManager.canUndo ? _undo : null,
                        tooltip: 'Undo',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.redo,
                          color: _historyManager.canRedo
                              ? Colors.black87
                              : Colors.grey,
                        ),
                        onPressed: _historyManager.canRedo ? _redo : null,
                        tooltip: 'Redo',
                      ),
                    ],
                  ),

                  if (_drawingMode == DrawingMode.draw) ...[
                    const Divider(),

                    // Color picker
                    ...DrawingColors.all.take(6).map((color) {
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedDrawingColor = color),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedDrawingColor == color
                                  ? Colors.orange
                                  : Colors.grey.shade300,
                              width: _selectedDrawingColor == color ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }),

                    const Divider(),

                    // Stroke width selector
                    ...StrokeWidths.all.map((width) {
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedStrokeWidth = width),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedStrokeWidth == width
                                  ? Colors.orange
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: width,
                              height: width,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
