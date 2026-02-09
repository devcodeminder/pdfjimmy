import 'dart:async';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Service for automatic page scrolling (hands-free reading)
class AutoScrollService {
  Timer? _scrollTimer;
  bool _isScrolling = false;
  int _scrollSpeed = 5; // seconds per page (default)
  int _totalPages = 0;
  PdfViewerController? _controller;

  bool get isScrolling => _isScrolling;
  int get scrollSpeed => _scrollSpeed;

  /// Start automatic scrolling
  void startAutoScroll(PdfViewerController controller, int totalPages) {
    if (_isScrolling) return;

    _controller = controller;
    _totalPages = totalPages;
    _isScrolling = true;

    _scrollTimer = Timer.periodic(Duration(seconds: _scrollSpeed), (timer) {
      if (_controller == null) {
        stopAutoScroll();
        return;
      }

      final currentPage = _controller!.pageNumber;

      if (currentPage < _totalPages) {
        _controller!.jumpToPage(currentPage + 1);
      } else {
        // Reached end, stop auto-scroll
        stopAutoScroll();
      }
    });
  }

  /// Stop automatic scrolling
  void stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _isScrolling = false;
    _controller = null;
  }

  /// Set scroll speed (seconds per page)
  void setScrollSpeed(int secondsPerPage) {
    _scrollSpeed = secondsPerPage.clamp(1, 60);

    // Restart timer with new speed if currently scrolling
    if (_isScrolling && _controller != null) {
      final controller = _controller!;
      final totalPages = _totalPages;
      stopAutoScroll();
      startAutoScroll(controller, totalPages);
    }
  }

  /// Toggle auto-scroll on/off
  void toggle(PdfViewerController controller, int totalPages) {
    if (_isScrolling) {
      stopAutoScroll();
    } else {
      startAutoScroll(controller, totalPages);
    }
  }

  /// Dispose and clean up resources
  void dispose() {
    stopAutoScroll();
  }
}
