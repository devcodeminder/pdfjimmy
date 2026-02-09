import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdfjimmy/services/dictionary.dart';
import 'package:pdfjimmy/services/translator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/pdf_controller.dart';
import '../services/pdf_service.dart';
import '../utils/file_helper.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final int initialPage;

  const PdfViewerScreen({
    Key? key,
    required this.filePath,
    this.initialPage = 0,
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with WidgetsBindingObserver {
  bool _showToolbar = true;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Syncfusion PDF viewer controller
  late PdfViewerController _pdfViewerController;

  // Search functionality
  PdfTextSearchResult? _searchResult;

  // View Settings
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.continuous;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pdfViewerController = PdfViewerController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<PdfController>();
      controller.setCurrentFile(widget.filePath);

      // Instant Reopen Logic
      int targetPage = widget.initialPage;
      if (widget.initialPage == 0) {
        final pdfFile = await PdfService.instance.getPdfFile(widget.filePath);
        if (pdfFile != null && pdfFile.lastPageRead > 0) {
          targetPage = pdfFile.lastPageRead;
        }
      }

      if (targetPage > 0) {
        // Jump to page (Syncfusion uses 1-based index)
        _pdfViewerController.jumpToPage(targetPage + 1);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    PaintingBinding.instance.imageCache.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Low memory detected. Clearing cache and optimizing...',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink,
      body: Stack(
        children: [
          // Logic 3: Zero lag zoom - SfPdfViewer outside of Consumer
          Container(
            color: Colors.white,
            child: SfPdfViewer.file(
              File(widget.filePath),
              controller: _pdfViewerController,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              canShowPaginationDialog: true,
              initialScrollOffset: Offset.zero,
              initialZoomLevel: 1.0,
              interactionMode: PdfInteractionMode.selection,
              scrollDirection: PdfScrollDirection.vertical,
              pageLayoutMode:
                  _pageLayoutMode, // Logic 1: Lazy loading (RAM save)
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                final controller = context.read<PdfController>();
                controller.setTotalPages(details.document.pages.count);
                controller.setReady(true);
                controller.savePdfFile(
                  widget.filePath,
                  details.document.pages.count,
                );
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                context.read<PdfController>().setErrorMessage(details.error);
              },
              onPageChanged: (PdfPageChangedDetails details) {
                // Determine new page (Syncfusion is 1-based in details)
                // Use debounce or just update?
                // Updating controller.currentPage triggers notifyListeners() which rebuilds overlays
                context.read<PdfController>().setCurrentPage(
                  details.newPageNumber - 1,
                );
              },
              onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
                if (details.selectedText != null &&
                    details.selectedText!.isNotEmpty) {
                  // Text selection logic
                }
              },
            ),
          ),

          // Layer 2: UI Overlays (Need Consumer for state updates)
          Consumer<PdfController>(
            builder: (context, controller, child) {
              return Stack(
                children: [
                  if (_showToolbar)
                    Container(
                      height: 100,
                      color: Colors.orange,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              FileHelper.getFileName(widget.filePath),
                              style: const TextStyle(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
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
                          IconButton(
                            icon: Icon(
                              controller.isBookmarked(controller.currentPage)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: Colors.white,
                            ),
                            onPressed: () => _toggleBookmark(controller),
                          ),
                          IconButton(
                            icon: const Icon(Icons.g_translate),
                            tooltip: 'Translator',
                            color: Colors.white,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TranslatorScreen(initialText: ''),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.menu_book),
                            tooltip: 'Dictionary',
                            color: Colors.white,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DictionaryScreen(),
                                ),
                              );
                            },
                          ),

                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Color.fromARGB(255, 248, 246, 246),
                            ),
                            onSelected: (value) =>
                                _handleMenuAction(value, controller),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share),
                                    SizedBox(width: 8),
                                    Text('Share'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'layout_mode',
                                child: Row(
                                  children: [
                                    const Icon(Icons.view_agenda),
                                    const SizedBox(width: 8),
                                    Text(
                                      _pageLayoutMode ==
                                              PdfPageLayoutMode.single
                                          ? 'Continuous Scroll'
                                          : 'Single Page Mode',
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'zoom_in',
                                child: Row(
                                  children: [
                                    Icon(Icons.zoom_in),
                                    SizedBox(width: 8),
                                    Text('Zoom In'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'zoom_out',
                                child: Row(
                                  children: [
                                    Icon(Icons.zoom_out),
                                    SizedBox(width: 8),
                                    Text('Zoom Out'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'fit_width',
                                child: Row(
                                  children: [
                                    Icon(Icons.fit_screen),
                                    SizedBox(width: 8),
                                    Text('Fit Width'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'page_info',
                                child: Row(
                                  children: [
                                    Icon(Icons.info),
                                    SizedBox(width: 8),
                                    Text('Page Info'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if (_showSearch)
                    Positioned(
                      top: MediaQuery.of(context).padding.top,
                      left: 10,
                      right: 10,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Search text...',
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(70),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
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
                                  ? () {
                                      _searchResult!.previousInstance();
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              onPressed: _searchResult != null
                                  ? () {
                                      _searchResult!.nextInstance();
                                    }
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

                  if (_showToolbar)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.orange.withValues(alpha: 0.9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.first_page,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  _pdfViewerController.jumpToPage(1),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.navigate_before,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  _pdfViewerController.previousPage(),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${controller.currentPage + 1} / ${controller.totalPages}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.navigate_next,
                                color: Colors.white,
                              ),
                              onPressed: () => _pdfViewerController.nextPage(),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.last_page,
                                color: Colors.white,
                              ),
                              onPressed: () => _pdfViewerController.jumpToPage(
                                controller.totalPages,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (!controller.isReady)
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading PDF...'),
                        ],
                      ),
                    ),

                  if (controller.errorMessage.isNotEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading PDF',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(controller.errorMessage),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
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
        setState(() {});
      });
    }
  }

  void _clearSearch() {
    _searchResult?.clear();
    _searchResult = null;
    setState(() {});
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

  Future<void> _handleMenuAction(
    String action,
    PdfController controller,
  ) async {
    switch (action) {
      case 'share':
        await Share.shareXFiles([XFile(widget.filePath)]);
        break;
      case 'layout_mode':
        setState(() {
          _pageLayoutMode = _pageLayoutMode == PdfPageLayoutMode.continuous
              ? PdfPageLayoutMode.single
              : PdfPageLayoutMode.continuous;
        });
        break;
      case 'zoom_in':
        _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25;
        break;
      case 'zoom_out':
        _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel - 0.25;
        break;
      case 'fit_width':
        _pdfViewerController.zoomLevel = 1.0;
        break;
      case 'page_info':
        _showPageInfo(controller);
        break;
    }
  }

  void _showPageInfo(PdfController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Information'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      FileHelper.getFileName(widget.filePath),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Current Page: ${controller.currentPage + 1}'),
              Text('Total Pages: ${controller.totalPages}'),
              Text(
                'Zoom Level: ${(_pdfViewerController.zoomLevel * 100).toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: FileHelper.getFileSize(widget.filePath),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      'File Size: ${FileHelper.formatFileSize(snapshot.data!)}',
                    );
                  }
                  return const Text('File Size: Loading...');
                },
              ),
            ],
          ),
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
}
