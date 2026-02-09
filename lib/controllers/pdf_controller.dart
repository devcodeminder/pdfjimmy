import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pdfjimmy/services/pdf_service.dart';
import '../models/bookmark_model.dart';
import 'dart:io';

class PdfController extends ChangeNotifier {
  final GetStorage _box = GetStorage(); // ✅ Persistent storage

  // Syncfusion PDF viewer controller
  PdfViewerController? _pdfViewerController;

  String? _currentFilePath;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  String _errorMessage = '';
  List<BookmarkModel> _bookmarks = [];
  List<PdfFileModel> _recentFiles = [];
  double _zoomLevel = 1.0;

  // ✅ Load from storage or default to false
  bool _isNightMode = GetStorage().read('nightMode') ?? false;
  int _currentThemeIndex = GetStorage().read('themeIndex') ?? 0;
  int _customColorValue = GetStorage().read('customColor') ?? 0xFF6366F1;

  static const List<Color> themeColors = [
    Color(0xFF6366F1), // Indigo (Default)
    Color(0xFF2563EB), // Blue
    Color(0xFF059669), // Emerald
    Color(0xFFDC2626), // Red
    Color(0xFFDB2777), // Pink
    Color(0xFF7C3AED), // Violet
    Color(0xFFEA580C), // Orange
  ];

  // Search functionality with Syncfusion
  String _searchQuery = '';
  PdfTextSearchResult? _searchResult;
  int _currentSearchIndex = -1;
  int _totalSearchResults = 0;

  // Getters
  PdfViewerController? get pdfViewerController => _pdfViewerController;
  String? get currentFilePath => _currentFilePath;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get isReady => _isReady;
  String get errorMessage => _errorMessage;
  List<BookmarkModel> get bookmarks => _bookmarks;
  List<PdfFileModel> get recentFiles => _recentFiles;
  double get zoomLevel => _zoomLevel;
  bool get isNightMode => _isNightMode;
  String get searchQuery => _searchQuery;
  PdfTextSearchResult? get searchResult => _searchResult;
  int get currentSearchIndex => _currentSearchIndex;
  int get totalSearchResults => _totalSearchResults;
  int get currentThemeIndex => _currentThemeIndex;

  Color get currentThemeColor => Colors.deepOrange;

  // Core Setters
  void setPdfViewerController(PdfViewerController controller) {
    _pdfViewerController = controller;
    notifyListeners();
  }

  void setCurrentPage(int page) {
    _currentPage = page;
    if (_currentFilePath != null) {
      PdfService.instance.updateLastPage(_currentFilePath!, page);
    }
    notifyListeners();
  }

  void setTotalPages(int pages) {
    _totalPages = pages;
    notifyListeners();
  }

  void setReady(bool ready) {
    _isReady = ready;
    notifyListeners();
  }

  void setErrorMessage(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void setCurrentFile(String filePath) {
    _currentFilePath = filePath;
    _loadBookmarks();
    notifyListeners();
  }

  void setZoomLevel(double zoom) {
    _zoomLevel = zoom;
    if (_pdfViewerController != null) {
      _pdfViewerController!.zoomLevel = zoom;
    }
    notifyListeners();
  }

  // ✅ Night Mode Persistence
  void toggleNightMode() {
    _isNightMode = !_isNightMode;
    _box.write('nightMode', _isNightMode); // ✅ Save to storage
    notifyListeners();
  }

  void setThemeIndex(int index) {
    if (index >= -1 && index < themeColors.length) {
      _currentThemeIndex = index;
      _box.write('themeIndex', index);
      notifyListeners();
    }
  }

  void setCustomThemeColor(Color color) {
    _customColorValue = color.value;
    _currentThemeIndex = -1; // Switch to custom mode
    _box.write('customColor', _customColorValue);
    _box.write('themeIndex', -1);
    notifyListeners();
  }

  // PDF Navigation with Syncfusion
  Future<void> goToPage(int page) async {
    if (_pdfViewerController != null && page >= 0 && page < _totalPages) {
      _pdfViewerController!.jumpToPage(
        page + 1,
      ); // Syncfusion uses 1-based indexing
      setCurrentPage(page);
    }
  }

  Future<void> nextPage() async {
    if (_currentPage < _totalPages - 1) {
      _pdfViewerController?.nextPage();
    }
  }

  Future<void> previousPage() async {
    if (_currentPage > 0) {
      _pdfViewerController?.previousPage();
    }
  }

  Future<void> firstPage() async {
    if (_pdfViewerController != null) {
      _pdfViewerController!.jumpToPage(1);
    }
  }

  Future<void> lastPage() async {
    if (_pdfViewerController != null) {
      _pdfViewerController!.jumpToPage(_totalPages);
    }
  }

  Future<void> zoomIn() async {
    if (_zoomLevel < 3.0) {
      final newZoom = _zoomLevel + 0.25;
      setZoomLevel(newZoom);
    }
  }

  Future<void> zoomOut() async {
    if (_zoomLevel > 0.5) {
      final newZoom = _zoomLevel - 0.25;
      setZoomLevel(newZoom);
    }
  }

  Future<void> resetZoom() async {
    setZoomLevel(1.0);
  }

  Future<void> fitWidth() async {
    // Syncfusion automatically fits to width when zoom is set to 1.0
    setZoomLevel(1.0);
  }

  // Bookmarks
  Future<void> addBookmark(String title, {String? note}) async {
    if (_currentFilePath == null) return;

    final file = File(_currentFilePath!);
    final bookmark = BookmarkModel(
      fileName: file.path.split('/').last,
      filePath: _currentFilePath!,
      pageNumber: _currentPage,
      title: title,
      createdAt: DateTime.now(),
      note: note,
    );

    await PdfService.instance.createBookmark(bookmark);
    await _loadBookmarks();
  }

  Future<void> removeBookmark(int bookmarkId) async {
    await PdfService.instance.deleteBookmark(bookmarkId);
    await _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (_currentFilePath != null) {
      _bookmarks = await PdfService.instance.getBookmarks(_currentFilePath);
      notifyListeners();
    }
  }

  Future<void> jumpToBookmark(BookmarkModel bookmark) async {
    await goToPage(bookmark.pageNumber);
  }

  // Recent Files
  Future<void> loadRecentFiles() async {
    _recentFiles = await PdfService.instance.getRecentFiles();
    notifyListeners();
  }

  Future<void> savePdfFile(String filePath, int totalPages) async {
    final file = File(filePath);
    final stat = await file.stat();

    final pdfFile = PdfFileModel(
      fileName: file.path.split('/').last,
      filePath: filePath,
      totalPages: totalPages,
      lastOpened: DateTime.now(),
      fileSize: stat.size,
    );

    await PdfService.instance.savePdfFile(pdfFile);
    await loadRecentFiles();
  }

  Future<void> removeRecentFile(String filePath) async {
    await PdfService.instance.deletePdfFile(filePath);
    await loadRecentFiles();
  }

  Future<void> clearAllHistory() async {
    await PdfService.instance.deleteAllPdfFiles();
    await loadRecentFiles();
  }

  // Enhanced Search with Syncfusion
  void searchText(String query) {
    _searchQuery = query;

    if (query.isEmpty) {
      clearSearch();
      return;
    }

    if (_pdfViewerController != null) {
      // Clear previous search
      _searchResult?.clear();

      // Perform new search
      _searchResult = _pdfViewerController!.searchText(query);

      if (_searchResult != null) {
        // Listen to search result changes
        _searchResult!.addListener(_onSearchResultChanged);
      }
    }

    notifyListeners();
  }

  void _onSearchResultChanged() {
    if (_searchResult != null) {
      _totalSearchResults = _searchResult!.totalInstanceCount;
      _currentSearchIndex = _searchResult!.currentInstanceIndex;
      notifyListeners();
    }
  }

  void nextSearchResult() {
    _searchResult?.nextInstance();
  }

  void previousSearchResult() {
    _searchResult?.previousInstance();
  }

  void clearSearch() {
    _searchResult?.clear();
    _searchResult = null;
    _searchQuery = '';
    _currentSearchIndex = -1;
    _totalSearchResults = 0;
    notifyListeners();
  }

  // Advanced search options
  void searchTextCaseSensitive(String query) {
    searchText(query);
  }

  void searchTextWholeWords(String query) {
    searchText(query);
  }

  // Bookmarked Page Check
  bool isBookmarked(int page) {
    return _bookmarks.any((bookmark) => bookmark.pageNumber == page);
  }

  BookmarkModel? getBookmarkForPage(int page) {
    try {
      return _bookmarks.firstWhere((bookmark) => bookmark.pageNumber == page);
    } catch (e) {
      return null;
    }
  }

  // Get bookmarks for current file
  List<BookmarkModel> getBookmarksForCurrentFile() {
    if (_currentFilePath == null) return [];
    return _bookmarks
        .where((bookmark) => bookmark.filePath == _currentFilePath)
        .toList();
  }

  // Page navigation helpers
  bool get canGoNext => _currentPage < _totalPages - 1;
  bool get canGoPrevious => _currentPage > 0;
  bool get hasSearchResults => _totalSearchResults > 0;

  // Progress calculation
  double get readingProgress {
    if (_totalPages == 0) return 0.0;
    return (_currentPage + 1) / _totalPages;
  }

  // Format page display
  String get pageDisplayText => '${_currentPage + 1} / $_totalPages';

  // Search results display
  String get searchResultsText {
    if (_totalSearchResults == 0) return 'No results';
    return '${_currentSearchIndex + 1} / $_totalSearchResults';
  }

  // Cleanup
  @override
  void dispose() {
    _searchResult?.removeListener(_onSearchResultChanged);
    _searchResult?.clear();
    _pdfViewerController?.dispose();
    super.dispose();
  }

  // Reset controller state
  void reset() {
    _currentFilePath = null;
    _currentPage = 0;
    _totalPages = 0;
    _isReady = false;
    _errorMessage = '';
    _bookmarks.clear();
    _zoomLevel = 1.0;
    clearSearch();
    notifyListeners();
  }

  // Get file info
  Map<String, dynamic> getFileInfo() {
    if (_currentFilePath == null) return {};

    final file = File(_currentFilePath!);
    return {
      'fileName': file.path.split('/').last,
      'filePath': _currentFilePath,
      'currentPage': _currentPage + 1,
      'totalPages': _totalPages,
      'zoomLevel': '${(_zoomLevel * 100).toStringAsFixed(0)}%',
      'readingProgress': '${(readingProgress * 100).toStringAsFixed(1)}%',
      'bookmarkCount': _bookmarks.length,
    };
  }
}
