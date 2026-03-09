import 'package:flutter/material.dart';

/// Overlay widget that displays TTS reading highlights over the PDF viewer.
///
/// COORDINATE SYSTEM NOTES:
/// - Syncfusion PdfTextExtractor returns word bounds in PDF points (1pt = 1/72 inch)
/// - Syncfusion SfPdfViewer renders the PDF scaled to fit the widget width
/// - The renderScale converts: PDF points → logical pixels (includes zoom)
/// - scrollOffset from PdfViewerController.scrollOffset is a full Offset:
///     .dy = vertical scroll in zoomed logical pixels
///     .dx = horizontal scroll in zoomed logical pixels (non-zero when zoomed+panned)
/// - At zoom > 1, horizontal scroll (dx) MUST be subtracted from X positions
///   because the page content is wider than the viewport.
class TtsHighlightOverlay extends StatelessWidget {
  final List<Rect> highlightRects; // In PDF points (from PdfTextExtractor)
  final Size pageSize; // In PDF points (from PdfPage.size)
  final int pageIndex; // 0-based page index of the page being READ (not viewed)
  final Offset
  scrollOffset; // Full Offset: dx=horizontal, dy=vertical (zoomed px)
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
  final Offset scrollOffset;
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

    // ── Coordinate System ─────────────────────────────────────────────────
    // SfPdfViewer scale at zoom=1: PDF fits viewer width exactly.
    // renderScale converts PDF points → zoomed logical pixels.
    //   renderScale = (viewerWidth / pageSize.width) * zoomLevel
    //
    // Page geometry in zoomed pixel space:
    //   pageTopY   = pageIndex * (pageHeightPx + spacing)
    //   pageWidth  = pageSize.width  * renderScale   (may overflow viewport when zoom>1)
    //   pageHeight = pageSize.height * renderScale
    //
    // Word position on screen (within this overlay's painted area):
    //   screenLeft = rect.left  * renderScale - scrollOffset.dx   ← dx for zoom pan
    //   screenTop  = rect.top   * renderScale + pageTopY - scrollOffset.dy
    //   screenRight  = rect.right  * renderScale - scrollOffset.dx
    //   screenBottom = rect.bottom * renderScale + pageTopY - scrollOffset.dy
    // ──────────────────────────────────────────────────────────────────────

    // Scale factor: PDF points → logical pixels (includes zoom)
    final double renderScale = (viewerWidth / pageSize.width) * zoomLevel;

    // Inter-page spacing used by SfPdfViewer (approximately 4px at zoom=1,
    // scales proportionally with zoom since all content coordinates scale).
    final double spacing = 4.0 * zoomLevel;
    final double pageHeightPx = pageSize.height * renderScale;

    // Y-position of the TOP of the reading page in the scrollable document
    final double pageTopY = pageIndex * (pageHeightPx + spacing);

    // Vertical offset to convert page-relative Y → overlay-relative Y
    final double offsetY = pageTopY - scrollOffset.dy;

    // Horizontal offset: when zoom > 1 user can pan horizontally.
    // scrollOffset.dx is the horizontal pan in zoomed logical pixels.
    final double offsetX = -scrollOffset.dx;

    // Fill paint
    final paint = Paint()
      ..color = highlightColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply;

    // Border paint
    final borderPaint = Paint()
      ..color = highlightColor.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final rect in highlightRects) {
      // Scale the PDF-point rect to logical pixels, then apply scroll offsets
      final double left = rect.left * renderScale + offsetX;
      final double top = rect.top * renderScale + offsetY;
      final double right = rect.right * renderScale + offsetX;
      final double bottom = rect.bottom * renderScale + offsetY;

      final Rect screenRect = Rect.fromLTRB(left, top, right, bottom);

      // Skip rects completely outside the visible area
      if (screenRect.bottom < 0 || screenRect.top > size.height) continue;
      if (screenRect.right < 0 || screenRect.left > size.width) continue;

      // Small horizontal padding, tight vertical fit to word height
      const double px = 3.0;
      const double py = 1.0;
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
