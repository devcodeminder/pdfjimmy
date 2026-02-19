import 'package:flutter/material.dart';

/// Overlay widget that displays TTS reading highlights over the PDF viewer.
///
/// COORDINATE SYSTEM NOTES:
/// - Syncfusion PdfTextExtractor returns word bounds in PDF points (1pt = 1/72 inch)
/// - Syncfusion SfPdfViewer renders the PDF scaled to fit the widget width
/// - The renderScale converts: PDF points → logical pixels
/// - scrollOffset from PdfViewerController.scrollOffset.dy is in logical pixels
class TtsHighlightOverlay extends StatelessWidget {
  final List<Rect> highlightRects; // In PDF points (from PdfTextExtractor)
  final Size pageSize; // In PDF points (from PdfPage.size)
  final int pageIndex; // 0-based page index
  final double scrollOffset; // In logical pixels (from PdfViewerController)
  final double zoomLevel; // From PdfViewerController.zoomLevel
  final Color highlightColor;

  const TtsHighlightOverlay({
    Key? key,
    required this.highlightRects,
    required this.pageSize,
    required this.pageIndex,
    required this.scrollOffset,
    required this.zoomLevel,
    this.highlightColor = Colors.greenAccent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the actual widget width (not MediaQuery screen width)
          // because the PDF viewer may have padding applied
          final double viewerWidth = constraints.maxWidth;

          return CustomPaint(
            painter: _HighlightPainter(
              highlightRects: highlightRects,
              pageSize: pageSize,
              pageIndex: pageIndex,
              scrollOffset: scrollOffset,
              zoomLevel: zoomLevel,
              highlightColor: highlightColor,
              viewerWidth: viewerWidth,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          );
        },
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final List<Rect> highlightRects;
  final Size pageSize;
  final int pageIndex;
  final double scrollOffset;
  final double zoomLevel;
  final Color highlightColor;
  final double viewerWidth;

  _HighlightPainter({
    required this.highlightRects,
    required this.pageSize,
    required this.pageIndex,
    required this.scrollOffset,
    required this.zoomLevel,
    required this.highlightColor,
    required this.viewerWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pageSize.width <= 0 || pageSize.height <= 0) return;
    if (highlightRects.isEmpty) return;

    // Scale factor: PDF points → logical pixels
    // SfPdfViewer scales the PDF to fit the viewer width at zoom=1.0
    final double renderScale = (viewerWidth / pageSize.width) * zoomLevel;

    // Inter-page spacing used by SfPdfViewer (approximately 4px at zoom=1)
    final double spacing = 4.0 * zoomLevel;
    final double pageHeightPx = pageSize.height * renderScale;

    // Y position of the top of this page in the scrollable document
    final double pageTopY = pageIndex * (pageHeightPx + spacing);

    // Convert scroll offset to position within the painted area
    final double offsetY = pageTopY - scrollOffset;

    // Fill paint
    final paint = Paint()
      ..color = highlightColor.withOpacity(0.40)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply;

    // Border paint
    final borderPaint = Paint()
      ..color = highlightColor.withOpacity(0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final rect in highlightRects) {
      // Scale the PDF-point rect to logical pixels
      final double left = rect.left * renderScale;
      final double top = rect.top * renderScale;
      final double right = rect.right * renderScale;
      final double bottom = rect.bottom * renderScale;

      // Apply page offset and scroll
      final Rect screenRect = Rect.fromLTRB(
        left,
        top + offsetY,
        right,
        bottom + offsetY,
      );

      // Skip rects that are completely outside the visible area
      if (screenRect.bottom < 0 || screenRect.top > size.height) continue;
      if (screenRect.right < 0 || screenRect.left > size.width) continue;

      // Small horizontal padding, no vertical padding (tight fit to word height)
      final double px = 3.0;
      final double py = 1.0;
      final Rect paddedRect = Rect.fromLTRB(
        (screenRect.left - px).clamp(0.0, size.width),
        (screenRect.top - py).clamp(0.0, size.height),
        (screenRect.right + px).clamp(0.0, size.width),
        (screenRect.bottom + py).clamp(0.0, size.height),
      );

      if (paddedRect.width <= 0 || paddedRect.height <= 0) continue;

      final rrect = RRect.fromRectAndRadius(
        paddedRect,
        const Radius.circular(3.0),
      );

      canvas.drawRRect(rrect, paint);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.highlightRects != highlightRects ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.pageIndex != pageIndex ||
        oldDelegate.viewerWidth != viewerWidth;
  }
}
