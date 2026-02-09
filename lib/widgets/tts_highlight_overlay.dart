import 'package:flutter/material.dart';

class TtsHighlightOverlay extends StatelessWidget {
  final List<Rect> highlightRects; // In PDF Points
  final Size pageSize; // In PDF Points
  final int pageIndex;
  final double scrollOffset;
  final double zoomLevel;
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
      child: CustomPaint(
        painter: _HighlightPainter(
          highlightRects: highlightRects,
          pageSize: pageSize,
          pageIndex: pageIndex,
          scrollOffset: scrollOffset,
          zoomLevel: zoomLevel,
          highlightColor: highlightColor,
          screenWidth: MediaQuery.of(context).size.width,
        ),
        size: Size.infinite,
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
  final double screenWidth;

  _HighlightPainter({
    required this.highlightRects,
    required this.pageSize,
    required this.pageIndex,
    required this.scrollOffset,
    required this.zoomLevel,
    required this.highlightColor,
    required this.screenWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pageSize.width <= 0) return;

    // Calculate scale based on 'Fit Width' logic which is standard for mobile PDF viewers
    // Effective PDF Width in Pixels = Screen Width * Zoom
    // Scale = Effective Width / Original PDF Width
    final double renderScale = (screenWidth / pageSize.width) * zoomLevel;

    // Calculate the vertical position of the target page
    // Syncfusion usually adds some spacing between pages.
    // Default inter-page spacing is often around 8 logical pixels.
    final double spacing = 8.0 * zoomLevel; // Scaling spacing too
    final double pageHeightInPixels = pageSize.height * renderScale;

    // Calculate Top Y of the current page in the scroll view
    final double pageTopY = pageIndex * (pageHeightInPixels + spacing);

    final paint = Paint()
      ..color = highlightColor.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    for (var rect in highlightRects) {
      // Calculate the highlight rect in screen pixels
      final Rect scaledRect = Rect.fromLTRB(
        rect.left * renderScale,
        rect.top * renderScale,
        rect.right * renderScale,
        rect.bottom * renderScale,
      );

      // Shift by page position and scroll offset
      // Also add top toolbar padding if the scrollOffset is 0 at the top of content
      // Usually scrollOffset includes the offset from the top of the content.
      final Rect drawRect = scaledRect.shift(
        Offset(
          0,
          pageTopY - scrollOffset + (spacing / 2),
        ), // Adjust for initial spacing if needed
      );

      // Use a slightly larger rect for better visibility
      final visibleRect = drawRect.inflate(2.0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(visibleRect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    // Simple list equality check or length check is better than deep compare for perf
    // Assuming new list instance on update
    return oldDelegate.highlightRects != highlightRects ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.zoomLevel != zoomLevel;
  }
}
