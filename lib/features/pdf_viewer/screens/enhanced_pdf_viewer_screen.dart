import 'package:pdfjimmy/core/services/offline_ai_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for compute()
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:ui'; // Needed for BackdropFilter

import 'package:pdfjimmy/core/services/dictionary.dart';
import 'package:pdfjimmy/core/services/translator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';
import 'package:pdfjimmy/features/pdf_viewer/controllers/pdf_controller.dart';
import 'package:pdfjimmy/core/utils/file_helper.dart';
import 'package:pdfjimmy/core/models/pdf_annotation_model.dart';
import 'package:pdfjimmy/core/models/drawing_model.dart';
import 'package:pdfjimmy/core/services/pdf_service.dart';
import 'package:pdfjimmy/core/services/action_history_manager.dart';
import 'package:pdfjimmy/core/services/auto_scroll_service.dart';
import 'package:pdfjimmy/core/services/pdf_tts_service.dart';
import 'package:pdfjimmy/core/widgets/drawing_overlay.dart';
import 'package:pdfjimmy/core/widgets/signature_overlay.dart';
import 'package:pdfjimmy/core/models/signature_placement_model.dart';
import 'package:pdfjimmy/core/models/signature_data.dart';
import 'package:pdfjimmy/features/signature/screens/signature_library_screen.dart';
import 'package:pdfjimmy/features/ai/screens/smart_search_screen.dart';
import 'package:pdfjimmy/core/widgets/tts_player_widget.dart';
import 'package:pdfjimmy/features/ai/screens/ai_translation_screen.dart';
import 'package:pdfjimmy/core/widgets/tts_highlight_overlay.dart';
import 'package:pdfjimmy/features/ai/widgets/movable_translator_widget.dart';
import 'package:pdfjimmy/features/signature/providers/signature_provider.dart';
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
  final ValueNotifier<Offset> _scrollOffsetNotifier = ValueNotifier(
    Offset.zero,
  );

  // UI State
  bool _showToolbar = true;
  bool _showSearch = false;
  bool _showBookmarks = false;
  bool _showNotes = false;
  bool _showHighlights = false;
  bool _isNightMode = false;
  bool _scrollLock = false;
  bool _isFabExpanded = false;
  bool _showTtsPlayer = false;
  bool _isDisposing = false;

  // PDF bytes loaded in background isolate to avoid JNI main-thread lock
  Uint8List? _pdfBytes;
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
  // Movable Translator state
  final ValueNotifier<PdfTextSelectionChangedDetails?> _textSelectionNotifier = ValueNotifier(null);
  Offset? _translatorCustomPosition;

  final PdfTtsService _ttsService = PdfTtsService();

  // GlobalKey to call seekToTapPosition on the TTS player
  final GlobalKey<TtsPlayerWidgetState> _ttsPlayerKey =
      GlobalKey<TtsPlayerWidgetState>();

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

      // Load PDF bytes in background isolate FIRST (avoids JNI lock on main thread)
      _loadPdfBytes();

      // Load last read page
      _loadLastReadPage();

      // Load annotations
      _loadAnnotations();

      // Load drawings
      _loadDrawings();

      // Load signatures
      _loadSignatures();
    });
  }

  /// Loads PDF file bytes in a background isolate via compute().
  /// Using SfPdfViewer.memory() with pre-loaded bytes avoids the
  /// JNI critical lock warning (21ms+ GC pauses) caused by SfPdfViewer.file()
  /// reading directly on the platform main thread.
  Future<void> _loadPdfBytes() async {
    try {
      final bytes = await compute(_readFileBytes, widget.filePath);
      if (mounted && !_isDisposing) {
        setState(() => _pdfBytes = bytes);
      }
    } catch (e) {
      debugPrint('Error pre-loading PDF bytes: $e');
    }
  }

  /// Top-level function required by compute() — must not be a closure.
  static Future<Uint8List> _readFileBytes(String path) async {
    return File(path).readAsBytes();
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
    final List<int> bytes = await File(widget.filePath).readAsBytes();
    final request = _PdfFlattenRequest(
      pdfBytes: Uint8List.fromList(bytes),
      drawings: _drawings,
      signaturePlacements: _signaturePlacements,
      signaturesMap: _signaturesMap,
      screenWidth: MediaQuery.of(context).size.width,
      zoomLevel: _pdfViewerController.zoomLevel,
    );

    return await compute(_flattenPdfIsolate, request);
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
    _textSelectionNotifier.dispose();

    // Dispose PDF viewer controller last
    _pdfViewerController.dispose();
    _toolbarAnimationController.dispose();
    _fabAnimationController.dispose();
    _scrollOffsetNotifier.dispose();
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
      // When TTS player is open, tapping the PDF should only SHOW the toolbar
      // (if it was hidden), never hide it. This prevents the play/pause button
      // tap from accidentally hiding the top toolbar and making controls disappear.
      if (_showTtsPlayer) {
        _showToolbar = true;
        _toolbarAnimationController.forward();
      } else {
        _showToolbar = !_showToolbar;
        if (_showToolbar) {
          _toolbarAnimationController.forward();
        } else {
          _toolbarAnimationController.reverse();
        }
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
                          child: ValueListenableBuilder<Offset>(
                            valueListenable: _scrollOffsetNotifier,
                            builder: (context, scrollOffset, _) {
                              return SignatureOverlay(
                                pageNumber: controller.currentPage,
                                placements: _signaturePlacements,
                                signaturesMap: _signaturesMap,
                                selectedPlacementId:
                                    _selectedSignaturePlacementId,
                                scrollOffset: scrollOffset.dy,
                                onSignatureSelected: (placementId) {
                                  setState(
                                    () => _selectedSignaturePlacementId =
                                        placementId,
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
                        // Absorb taps so they don't bubble up to the parent
                        // GestureDetector(onTap: _toggleToolbar). Without this,
                        // tapping play/pause also hides the top toolbar.
                        child: GestureDetector(
                          onTap: () {}, // absorb tap — do nothing
                          child: TtsPlayerWidget(
                            key: _ttsPlayerKey,
                            filePath: widget.filePath,
                            currentPage: controller.currentPage,
                            totalPages: controller.totalPages,
                            ttsService: _ttsService, // Pass persistent service
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
                                  });
                                  if (rects != null && rects.isNotEmpty) {
                                    _autoScrollToHighlight(rects, pageSize);
                                  }
                                },
                            currentHighlightColor: _ttsHighlightColor,
                            onHighlightColorChanged: (color) {
                              setState(() => _ttsHighlightColor = color);
                            },
                          ),
                        ),
                      ),
                    
                    // Movable Translator Widget (Using ValueNotifier to avoid recreating SfPdfViewer)
                    Positioned.fill(
                      child: ValueListenableBuilder<PdfTextSelectionChangedDetails?>(
                        valueListenable: _textSelectionNotifier,
                        builder: (context, selectionDetails, child) {
                          if (selectionDetails?.selectedText != null &&
                              selectionDetails?.globalSelectedRegion != null) {
                            return Stack(
                              children: [
                                MovableTranslatorWidget(
                                  initialText: selectionDetails!.selectedText!,
                                  initialPosition: _translatorCustomPosition ?? 
                                     Offset(
                                       (MediaQuery.of(context).size.width / 2 - 60).toDouble(), // Center horizontally
                                       (MediaQuery.of(context).size.height - 120).toDouble() // Fixed at bottom
                                     ),
                                  onPositionChanged: (newPos) => _translatorCustomPosition = newPos,
                                  onClose: () => _textSelectionNotifier.value = null,
                                  onTranslateExpanded: () {
                                    _pdfViewerController.clearSelection();
                                  },
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
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

  void _autoScrollToHighlight(List<Rect> rects, Size pageSize) {
    if (rects.isEmpty || pageSize.width <= 0) return;

    // Use the PDF viewport width (same as LayoutBuilder constraints in overlay)
    // MediaQuery.size.width equals the viewport width on full-screen PDF viewers.
    final double viewerWidth = MediaQuery.of(context).size.width;
    final double zoomLevel = _pdfViewerController.zoomLevel;

    // Scale factor: PDF points → logical pixels (must match overlay painter)
    final double renderScale = (viewerWidth / pageSize.width) * zoomLevel;

    // Inter-page spacing used by SfPdfViewer (approx. 4px at zoom=1)
    final double spacing = 4.0 * zoomLevel;
    final double pageHeightPx = pageSize.height * renderScale;

    // Use TTS service's reading page (not viewer's visible page) to match overlay
    final int pageIndex = _ttsService.currentPageIndex;

    // Global Y offset of this page in the continuous scroll view
    final double pageTopY = pageIndex * (pageHeightPx + spacing);

    // Global Y boundaries of the current word
    final double wordGlobalTopY = pageTopY + rects.first.top * renderScale;
    final double wordGlobalBottomY =
        pageTopY + rects.first.bottom * renderScale;

    // Current scroll position and visible area
    final double scrollY = _pdfViewerController.scrollOffset.dy;

    // Visible height: Top app bar (~60) + bottom TTS player (~210) + margin
    final double visibleHeight = MediaQuery.of(context).size.height - 300;

    if (visibleHeight <= 0) return; // Safety check

    // If word is below the visible area, scroll down
    if (wordGlobalBottomY > scrollY + visibleHeight) {
      // Put word closer to the top-middle of the screen
      final double targetScrollY = wordGlobalTopY - (visibleHeight * 0.25);
      _pdfViewerController.jumpTo(
        xOffset: _pdfViewerController.scrollOffset.dx,
        yOffset: targetScrollY,
      );
    }
    // If word is above the visible area, scroll up
    else if (wordGlobalTopY < scrollY) {
      final double targetScrollY = wordGlobalTopY - (visibleHeight * 0.25);
      _pdfViewerController.jumpTo(
        xOffset: _pdfViewerController.scrollOffset.dx,
        yOffset: targetScrollY < 0 ? 0 : targetScrollY,
      );
    }
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
                if (notification is ScrollUpdateNotification) {
                  _scrollOffsetNotifier.value =
                      _pdfViewerController.scrollOffset;
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
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        _pdfBytes != null
                            ? SfPdfViewer.memory(
                                _pdfBytes!,
                                key: ValueKey(widget.filePath),
                                password: widget.password,
                                controller: _pdfViewerController,
                                enableDoubleTapZooming:
                                    !_scrollLock && _enableDoubleTapZoom,
                                enableTextSelection: !_scrollLock,
                                canShowScrollHead: true,
                                canShowScrollStatus: true,
                                canShowPaginationDialog: !_scrollLock,
                                initialScrollOffset: Offset.zero,
                                initialZoomLevel: 1.0,
                                interactionMode: _scrollLock
                                    ? PdfInteractionMode.pan
                                    : PdfInteractionMode.selection,
                                scrollDirection: PdfScrollDirection.vertical,
                                pageLayoutMode: _pageLayoutMode,
                                currentSearchTextHighlightColor: _showTtsPlayer
                                    ? _ttsHighlightColor.withValues(alpha: 0.6)
                                    : Colors.orangeAccent.withValues(
                                        alpha: 0.5,
                                      ),
                                otherSearchTextHighlightColor: _showTtsPlayer
                                    ? Colors.transparent
                                    : Colors.yellow.withValues(alpha: 0.3),
                                onDocumentLoaded:
                                    (PdfDocumentLoadedDetails details) {
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
                                        controller.setErrorMessage(
                                          details.error,
                                        );
                                      }
                                    },
                                onPageChanged: (PdfPageChangedDetails details) {
                                  if (mounted && !_isDisposing) {
                                    if (_enableHaptics)
                                      HapticFeedback.selectionClick();
                                    controller.setCurrentPage(
                                      details.newPageNumber - 1,
                                    );
                                  }
                                },
                                onTextSelectionChanged:
                                    (PdfTextSelectionChangedDetails details) {
                                      if (details.selectedText != null &&
                                          details.selectedText!
                                              .trim()
                                              .isNotEmpty) {
                                        // Update without setState to prevent interrupting text selection drag
                                        if (_textSelectionNotifier.value?.selectedText != details.selectedText) {
                                          _textSelectionNotifier.value = details;
                                          _translatorCustomPosition = null; 
                                        }
                                      }
                                    },
                              )
                            : const Center(child: CircularProgressIndicator()),
                        if (_showTtsPlayer &&
                            _currentTtsHighlightRects != null &&
                            _currentTtsPageSize != Size.zero)
                          Positioned.fill(
                            child: TtsHighlightOverlay(
                              highlightRects: _currentTtsHighlightRects!,
                              pageSize: _currentTtsPageSize,
                              // Use the TTS service's reading page, NOT the viewer's
                              // visible page. These differ when TTS auto-advances pages
                              // before the viewer scrolls, causing a one-page Y-offset.
                              pageIndex: _ttsService.currentPageIndex,
                              // Pass the FULL Offset (dx+dy). dx is non-zero when the
                              // user has zoomed in and panned horizontally — without it
                              // the highlight X position is wrong on zoomed pages.
                              scrollOffset: _pdfViewerController.scrollOffset,
                              zoomLevel: _pdfViewerController.zoomLevel,
                              highlightColor: _ttsHighlightColor,
                            ),
                          ),
                        // Invisible tap overlay for sentence-seek while TTS is active
                        if (_showTtsPlayer)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (ctx, constraints) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapDown: (details) {
                                    // ─── Correct Coordinate Conversion ───
                                    // The GestureDetector lives inside Padding(top:60)
                                    // so localPosition.dy=0 is already the top of the
                                    // PDF content area. No extra offset needed.
                                    //
                                    // TtsHighlightOverlay painter formula (forward):
                                    //   screenY = pdfPt * renderScale + pageTopY - scrollOffset
                                    //
                                    // Inverse (what we need):
                                    //   pdfPt = (screenY + scrollOffset - pageTopY) / renderScale
                                    //
                                    final double viewerWidth =
                                        constraints.maxWidth;
                                    final double scrollOffsetY =
                                        _pdfViewerController.scrollOffset.dy;
                                    final double zoom =
                                        _pdfViewerController.zoomLevel;

                                    // pageSize is known from the last word-spoken callback.
                                    // Fall back to a rough estimate if not yet available.
                                    final Size pageSize =
                                        (_currentTtsPageSize != Size.zero)
                                        ? _currentTtsPageSize
                                        : _ttsService.currentPageSize;

                                    final double renderScale =
                                        pageSize.width > 0
                                        ? (viewerWidth / pageSize.width) * zoom
                                        : zoom;

                                    // Y of the top of the current viewed page in the
                                    // continuous scroll coordinate space.
                                    final double pageHeightPx =
                                        pageSize.height * renderScale;
                                    final double spacing = 4.0 * zoom;
                                    final double pageWithSpacingPx = pageHeightPx + spacing;

                                    final double screenY =
                                        details.localPosition.dy;
                                    final double totalY = screenY + scrollOffsetY;

                                    // Determine the actual page that was tapped based on total scroll Y
                                    int tappedPageIndex = (totalY / pageWithSpacingPx).floor();
                                    if (tappedPageIndex < 0) tappedPageIndex = 0;
                                    if (tappedPageIndex >= controller.totalPages) {
                                      tappedPageIndex = controller.totalPages - 1;
                                    }

                                    final double actualPageTopY = tappedPageIndex * pageWithSpacingPx;
                                    final double pdfY = (totalY - actualPageTopY) / renderScale;

                                    print(
                                      'AI Reader: Tap — screenY=$screenY scrollY=$scrollOffsetY '
                                      'tappedIndex=$tappedPageIndex pageTopY=$actualPageTopY renderScale=$renderScale pdfY=$pdfY',
                                    );

                                    // Haptic feedback
                                    HapticFeedback.mediumImpact();

                                    // Show brief hint
                                    ScaffoldMessenger.of(
                                      context,
                                    ).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(
                                              Icons.record_voice_over,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Reading from tapped position…',
                                            ),
                                          ],
                                        ),
                                        backgroundColor:
                                            Colors.deepOrange.shade700,
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );

                                    _ttsPlayerKey.currentState
                                        ?.seekToTapPosition(
                                          pdfY,
                                          screenY: screenY,
                                          scrollOffsetY: scrollOffsetY,
                                          viewerWidth: viewerWidth,
                                          zoom: zoom,
                                          pageIndex: tappedPageIndex,
                                        );
                                  },
                                );
                              },
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
      ),
    );
  }

  // --- PDF Flattening Isolate ---

  static Future<List<int>> _flattenPdfIsolate(
    _PdfFlattenRequest request,
  ) async {
    final pdf_lib.PdfDocument document = pdf_lib.PdfDocument(
      inputBytes: request.pdfBytes,
    );

    double accumulatedPageHeight = 0.0;

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final pageSize = page.size;
      final double renderScale =
          (request.screenWidth / pageSize.width) * request.zoomLevel;
      final double pageHeightInPixels = pageSize.height * renderScale;

      // 1. Burn Drawings
      final pageDrawings = request.drawings
          .where((d) => d.pageNumber == i)
          .toList();

      for (final drawing in pageDrawings) {
        if (drawing.points.isEmpty) continue;
        final pdfPath = pdf_lib.PdfPath();
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
            255,
          ),
          width: drawing.strokeWidth / renderScale,
        );
        page.graphics.drawPath(pdfPath, pen: pdfPen);
      }

      // 2. Burn Signatures
      final pageSignatures = request.signaturePlacements
          .where((p) => p.pageNumber == i)
          .toList();

      for (final placement in pageSignatures) {
        final sigData = request.signaturesMap[placement.signatureId];
        if (sigData != null) {
          final image = pdf_lib.PdfBitmap(sigData.imageData);
          page.graphics.save();

          final double pdfX = placement.position.dx / renderScale;
          final double containerW = 160.0 * placement.scale;
          final double containerH = 80.0 * placement.scale;

          final double imageAspectRatio =
              image.width.toDouble() / image.height.toDouble();
          final double containerAspectRatio = containerW / containerH;

          double drawW, drawH;
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

          double targetY =
              (placement.position.dy - accumulatedPageHeight) / renderScale;
          targetY =
              targetY + pdfOffsetY - (pdfDrawH * 0.20) - (80.0 / renderScale);

          page.graphics.translateTransform(finalPdfX, targetY);
          page.graphics.rotateTransform(placement.rotation * 180 / 3.14159);
          page.graphics.drawImage(
            image,
            Rect.fromLTWH(0, 0, pdfDrawW, pdfDrawH),
          );
          page.graphics.restore();
        }
      }
      accumulatedPageHeight += pageHeightInPixels + 5.0;
    }

    final List<int> savedBytes = await document.save();
    document.dispose();
    return savedBytes;
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
      barrierColor: Colors.black.withValues(alpha: 0.8), // Dark overlay
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
                  color: const Color(
                    0xFF0F1115,
                  ).withValues(alpha: 0.95), // Deep dark glassy base
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0280F8), Color(0xFFFF9500)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0280F8,
                                ).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'QUICK ACTIONS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.2, curve: Curves.easeOutBack),
                    const SizedBox(height: 32),

                    // Grid Options
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 24,
                          alignment: WrapAlignment.center,
                          children:
                              [
                                    _buildGameMenuButton(
                                      icon: Icons.bookmark_border_rounded,
                                      label: 'Bookmarks',
                                      color: Colors.blue,
                                      onTap: () => setState(
                                        () => _showBookmarks = !_showBookmarks,
                                      ),
                                    ),
                                    _buildGameMenuButton(
                                      icon: Icons.note_alt_outlined,
                                      label: 'Notes',
                                      color: Colors.purple,
                                      onTap: () => setState(
                                        () => _showNotes = !_showNotes,
                                      ),
                                    ),
                                    _buildGameMenuButton(
                                      icon: Icons.record_voice_over_rounded,
                                      label: 'Read',
                                      color: Colors.teal,
                                      onTap: () => setState(
                                        () => _showTtsPlayer = !_showTtsPlayer,
                                      ),
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
                                      onTap: () => setState(
                                        () => _scrollLock = !_scrollLock,
                                      ),
                                    ),
                                    _buildGameMenuButton(
                                      icon: _autoScrollService.isScrolling
                                          ? Icons.stop_circle_outlined
                                          : Icons.slideshow_rounded,
                                      label: _autoScrollService.isScrolling
                                          ? 'Stop Scroll'
                                          : 'Auto Scroll',
                                      color: Colors.amberAccent.shade700,
                                      onTap: () =>
                                          _toggleAutoScroll(controller),
                                    ),
                                    _buildGameMenuButton(
                                      icon: Icons.translate_rounded,
                                      label: 'Translate',
                                      color: Colors.lightGreen,
                                      onTap: () {
                                        if (controller.currentFilePath !=
                                            null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AITranslationScreen(
                                                    filePath: widget.filePath,
                                                    fileName:
                                                        FileHelper.getFileName(
                                                          widget.filePath,
                                                        ),
                                                    initialPage:
                                                        controller.currentPage,
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
                                      onTap: () =>
                                          _showDocumentInfo(controller),
                                    ),
                                    _buildGameMenuButton(
                                      icon: Icons.touch_app_rounded,
                                      label: 'Gestures',
                                      color: Colors.brown,
                                      onTap: _showGestureSettingsDialog,
                                    ),
                                  ]
                                  .animate(interval: 40.ms)
                                  .fadeIn(duration: 400.ms)
                                  .scale(
                                    begin: const Offset(0.5, 0.5),
                                    curve: Curves.easeOutBack,
                                    duration: 600.ms,
                                  )
                                  .moveY(
                                    begin: 15,
                                    curve: Curves.easeOutBack,
                                    duration: 600.ms,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child:
                          ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'CLOSE MENU',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: Colors.white70,
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 500.ms)
                              .slideY(begin: 0.3, curve: Curves.easeOutBack),
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
                size: 64, // Increased size for better presence
                iconSize: 28,
                onTap: null, // Tap handled by outer gesture detector
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(
                begin: 0,
                end: -6,
                duration: 1200.ms,
                curve: Curves.easeInOut,
              )
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
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
              color: color.withValues(alpha: 0.4),
              offset: const Offset(0, 8),
              blurRadius: 10,
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.transparent,
              ],
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
      left: 16,
      right: 16,
      child:
          ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isNightMode
                          ? const Color(0xFF0F1115).withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isNightMode
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          Icons.search_rounded,
                          color: Colors.purpleAccent.shade100,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Material(
                            type: MaterialType.transparency,
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: TextStyle(
                                color: _isNightMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              cursorColor: Colors.purpleAccent,
                              decoration: InputDecoration(
                                hintText: 'Search document...',
                                hintStyle: TextStyle(
                                  color: _isNightMode
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black54,
                                  fontFamily: 'Outfit',
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                suffixText: _searchResult != null
                                    ? '${_searchResult!.currentInstanceIndex + 1}/${_searchResult!.totalInstanceCount}'
                                    : null,
                                suffixStyle: const TextStyle(
                                  color: Colors.purpleAccent,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              onChanged: (value) => _performSearch(value),
                              onSubmitted: (value) => _performSearch(value),
                            ),
                          ),
                        ),
                        if (_searchResult != null) ...[
                          Container(
                            width: 1,
                            height: 24,
                            color: _isNightMode
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.1),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          _buildSearchIconButton(
                            icon: Icons.keyboard_arrow_up_rounded,
                            color: _isNightMode
                                ? Colors.white70
                                : Colors.black87,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _searchResult!.previousInstance();
                            },
                          ),
                          _buildSearchIconButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            color: _isNightMode
                                ? Colors.white70
                                : Colors.black87,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _searchResult!.nextInstance();
                            },
                          ),
                        ],
                        Container(
                          width: 1,
                          height: 24,
                          color: _isNightMode
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        _buildSearchIconButton(
                          icon: Icons.close_rounded,
                          color: Colors.redAccent,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _showSearch = false);
                            _searchController.clear();
                            _clearSearch();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: -0.2, curve: Curves.easeOutBack),
    );
  }

  Widget _buildSearchIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: (color ?? Colors.white).withValues(alpha: 0.2),
        highlightColor: (color ?? Colors.white).withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color ?? Colors.white70, size: 22),
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
                ? const Color(0xFF2C2C2C).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              // Gentle Glow instead of heavy shadow
              BoxShadow(
                color: _isNightMode
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
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
                  color: Colors.grey.withValues(alpha: 0.2),
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
                  color: Colors.grey.withValues(alpha: 0.2),
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
                  color: Colors.grey.withValues(alpha: 0.2),
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
    // Note accent colors - cycle through these
    final noteColors = [
      const Color(0xFFFFD93D), // Yellow
      const Color(0xFF6BCB77), // Green
      const Color(0xFF4D96FF), // Blue
      const Color(0xFFFF6B6B), // Red
      const Color(0xFFB48EFC), // Purple
      const Color(0xFFFF922B), // Orange
    ];

    return Positioned(
      right: 16,
      top: 100,
      bottom: 100,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
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
                // Header with Add button
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
                      Icon(
                        Icons.note_alt_rounded,
                        size: 18,
                        color: const Color(0xFFB48EFC),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notes (${_notes.length})',
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
                      // Add Note Button
                      GestureDetector(
                        onTap: () => _addNote(controller),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB48EFC), Color(0xFF6C63FF)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      InkWell(
                        onTap: () => setState(() => _showNotes = false),
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

                // Notes list or empty state
                Expanded(
                  child: _notes.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFB48EFC,
                                ).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.note_alt_outlined,
                                size: 36,
                                color: Color(0xFFB48EFC),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notes yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _isNightMode
                                    ? Colors.white70
                                    : const Color(0xFF2D3436),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap + Add to create a note\nfor the current page',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isNightMode
                                    ? Colors.white38
                                    : Colors.grey[500],
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () => _addNote(controller),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFB48EFC),
                                      Color(0xFF6C63FF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Add First Note',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            final accentColor =
                                noteColors[index % noteColors.length];
                            return Dismissible(
                              key: Key('note_${note.id ?? index}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red[700],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: const Text('Delete Note?'),
                                        content: const Text(
                                          'This note will be permanently deleted.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                              },
                              onDismissed: (direction) async {
                                _historyManager.addAction(
                                  HistoryAction(
                                    type: ActionType.removeNote,
                                    data: note,
                                  ),
                                );
                                await PdfService.instance.deleteNote(note.id!);
                                await _loadAnnotations();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Note deleted'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: _undo,
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: GestureDetector(
                                onTap: () {
                                  _pdfViewerController.jumpToPage(
                                    note.pageNumber + 1,
                                  );
                                  setState(() => _showNotes = false);
                                },
                                onLongPress: () => _editNote(note),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: _isNightMode
                                        ? const Color(0xFF3A3A3A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border(
                                      left: BorderSide(
                                        color: accentColor,
                                        width: 4,
                                      ),
                                    ),
                                    boxShadow: _isNightMode
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: accentColor.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: accentColor.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Page ${note.pageNumber + 1}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: accentColor,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () => _editNote(note),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _isNightMode
                                                      ? Colors.white10
                                                      : Colors.grey.withValues(
                                                          alpha: 0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.edit_outlined,
                                                  size: 14,
                                                  color: _isNightMode
                                                      ? Colors.white54
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          note.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: _isNightMode
                                                ? Colors.white
                                                : const Color(0xFF2D3436),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (note.content.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            note.content,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: _isNightMode
                                                  ? Colors.white60
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatNoteDate(
                                            note.updatedAt ?? note.createdAt,
                                          ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _isNightMode
                                                ? Colors.white30
                                                : Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNoteDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _isNightMode
                ? const Color(0xFF1E1E2C)
                : const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Bookmark',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _isNightMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),

              // Title Field
              TextField(
                controller: titleController,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _isNightMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: GoogleFonts.poppins(
                    color: _isNightMode ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: _isNightMode
                      ? const Color(0xFF2B2B40)
                      : Colors.white,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _isNightMode
                          ? Colors.transparent
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF0280F8),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note Field
              TextField(
                controller: noteController,
                maxLines: 3,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _isNightMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: GoogleFonts.poppins(
                    color: const Color(0xFF0280F8),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: _isNightMode
                      ? const Color(0xFF2B2B40)
                      : Colors.white,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _isNightMode
                          ? Colors.transparent
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF0280F8),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0280F8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0280F8).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        controller.addBookmark(
                          titleController.text.trim(),
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bookmark added')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0280F8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Add',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNote(PdfController controller) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final currentPage = controller.currentPage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _isNightMode ? const Color(0xFF2C2C2C) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB48EFC), Color(0xFF6C63FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.note_add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Note',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _isNightMode
                                ? Colors.white
                                : const Color(0xFF2D3436),
                          ),
                        ),
                        Text(
                          'Page ${currentPage + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFB48EFC),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _isNightMode ? Colors.white54 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(
                  color: _isNightMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Note title...',
                  hintStyle: TextStyle(
                    color: _isNightMode ? Colors.white30 : Colors.grey[400],
                  ),
                  prefixIcon: const Icon(
                    Icons.title_rounded,
                    size: 20,
                    color: Color(0xFFB48EFC),
                  ),
                  filled: true,
                  fillColor: _isNightMode
                      ? Colors.white10
                      : const Color(0xFFF8F4FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFB48EFC),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                style: TextStyle(
                  color: _isNightMode ? Colors.white : Colors.black87,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Write your note here...',
                  hintStyle: TextStyle(
                    color: _isNightMode ? Colors.white30 : Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: _isNightMode
                      ? Colors.white10
                      : const Color(0xFFF8F4FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFB48EFC),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _isNightMode
                              ? Colors.white60
                              : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a title'),
                            ),
                          );
                          return;
                        }
                        final newNote = PdfNote(
                          filePath: widget.filePath,
                          pageNumber: currentPage,
                          title: title,
                          content: contentController.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        final id = await PdfService.instance.createNote(
                          newNote,
                        );
                        _historyManager.addAction(
                          HistoryAction(
                            type: ActionType.addNote,
                            data: newNote.copyWith(id: id),
                          ),
                        );
                        await _loadAnnotations();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Note added!'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF6C63FF),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Save Note',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editNote(PdfNote note) {
    final titleController = TextEditingController(text: note.title);
    final contentController = TextEditingController(text: note.content);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _isNightMode ? const Color(0xFF2C2C2C) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6BCB77), Color(0xFF20BF55)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Note',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _isNightMode
                                ? Colors.white
                                : const Color(0xFF2D3436),
                          ),
                        ),
                        Text(
                          'Page ${note.pageNumber + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6BCB77),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _isNightMode ? Colors.white54 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(
                  color: _isNightMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Note title...',
                  hintStyle: TextStyle(
                    color: _isNightMode ? Colors.white30 : Colors.grey[400],
                  ),
                  prefixIcon: const Icon(
                    Icons.title_rounded,
                    size: 20,
                    color: Color(0xFF6BCB77),
                  ),
                  filled: true,
                  fillColor: _isNightMode
                      ? Colors.white10
                      : const Color(0xFFF4FFF6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF6BCB77),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                style: TextStyle(
                  color: _isNightMode ? Colors.white : Colors.black87,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Write your note here...',
                  hintStyle: TextStyle(
                    color: _isNightMode ? Colors.white30 : Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: _isNightMode
                      ? Colors.white10
                      : const Color(0xFFF4FFF6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF6BCB77),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _isNightMode
                              ? Colors.white60
                              : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Title cannot be empty'),
                            ),
                          );
                          return;
                        }
                        final updatedNote = note.copyWith(
                          title: title,
                          content: contentController.text.trim(),
                          updatedAt: DateTime.now(),
                        );
                        await PdfService.instance.updateNote(updatedNote);
                        await _loadAnnotations();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Note updated!'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF20BF55),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF20BF55),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Update Note',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

class _TranslationBottomSheet extends StatefulWidget {
  final String initialText;

  const _TranslationBottomSheet({Key? key, required this.initialText})
    : super(key: key);

  @override
  State<_TranslationBottomSheet> createState() =>
      _TranslationBottomSheetState();
}

class _TranslationBottomSheetState extends State<_TranslationBottomSheet> {
  String _translatedText = '';
  bool _isTranslating = false;
  String _selectedLanguage = 'ta'; // Tamil by default for Lens like translation

  final Map<String, String> _languages = {
    'en': 'English',
    'hi': 'Hindi',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'kn': 'Kannada',
  };

  @override
  void initState() {
    super.initState();
    _translateText();
  }

  Future<void> _translateText() async {
    if (widget.initialText.trim().isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    try {
      final translator = GoogleTranslator();
      final translation = await translator.translate(
        widget.initialText,
        to: _selectedLanguage,
      );
      if (mounted) {
        setState(() {
          _translatedText = translation.text;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = 'Translation failed: $e';
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFF2C2C2C), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.g_translate_rounded,
                color: Color(0xFF00FFCC),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Lens Translation',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: const Color(0xFF2C2C2C),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white70,
                    ),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != _selectedLanguage) {
                        setState(() {
                          _selectedLanguage = newValue;
                        });
                        _translateText();
                      }
                    },
                    items: _languages.entries.map<DropdownMenuItem<String>>((
                      entry,
                    ) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Original Text',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              widget.initialText,
              style: GoogleFonts.roboto(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Translation',
            style: GoogleFonts.outfit(
              color: const Color(0xFF00FFCC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFCC).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00FFCC).withValues(alpha: 0.3),
              ),
            ),
            child: _isTranslating
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF00FFCC),
                      ),
                    ),
                  )
                : Text(
                    _translatedText,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _translatedText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Translation copied to clipboard'),
                      backgroundColor: Color(0xFF00FFCC),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                label: const Text(
                  'Copy',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  // Keep text selection in SfPdfViewer intact but close bottom sheet
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check, size: 18),
                label: Text(
                  'Done',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// DTO for PDF Flattening Isolate
class _PdfFlattenRequest {
  final Uint8List pdfBytes;
  final List<DrawingPath> drawings;
  final List<SignaturePlacement> signaturePlacements;
  final Map<String, SignatureData> signaturesMap;
  final double screenWidth;
  final double zoomLevel;

  _PdfFlattenRequest({
    required this.pdfBytes,
    required this.drawings,
    required this.signaturePlacements,
    required this.signaturesMap,
    required this.screenWidth,
    required this.zoomLevel,
  });
}
