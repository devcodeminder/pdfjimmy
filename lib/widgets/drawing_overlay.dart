import 'package:flutter/material.dart';
import 'package:pdfjimmy/models/drawing_model.dart';

/// Custom painter for drawing paths on PDF
class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final DrawingPath? currentPath;

  DrawingPainter({required this.paths, this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all completed paths
    for (final path in paths) {
      _drawPath(canvas, path);
    }

    // Draw current path being drawn
    if (currentPath != null && currentPath!.points.isNotEmpty) {
      _drawPath(canvas, currentPath!);
    }
  }

  void _drawPath(Canvas canvas, DrawingPath drawingPath) {
    if (drawingPath.points.isEmpty) return;

    final paint = Paint()
      ..color = drawingPath.color
      ..strokeWidth = drawingPath.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(drawingPath.points.first.dx, drawingPath.points.first.dy);

    for (int i = 1; i < drawingPath.points.length; i++) {
      path.lineTo(drawingPath.points[i].dx, drawingPath.points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.paths != paths || oldDelegate.currentPath != currentPath;
  }
}

/// Drawing overlay widget that captures touch input
class DrawingOverlay extends StatefulWidget {
  final int pageNumber;
  final List<DrawingPath> existingDrawings;
  final Color selectedColor;
  final double strokeWidth;
  final DrawingMode drawingMode; // Changed from isDrawingEnabled
  final Function(DrawingPath) onDrawingComplete;
  final Function(int)? onDrawingErased; // Callback when drawing is erased
  final String filePath;
  final double eraserRadius; // Eraser size

  const DrawingOverlay({
    Key? key,
    required this.pageNumber,
    required this.existingDrawings,
    required this.selectedColor,
    required this.strokeWidth,
    required this.drawingMode,
    required this.onDrawingComplete,
    this.onDrawingErased,
    required this.filePath,
    this.eraserRadius = 20.0,
  }) : super(key: key);

  @override
  State<DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<DrawingOverlay> {
  DrawingPath? _currentPath;
  final List<int> _erasedDrawingIds = [];

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.drawingMode != DrawingMode.none;

    return GestureDetector(
      onPanStart: isActive ? _onPanStart : null,
      onPanUpdate: isActive ? _onPanUpdate : null,
      onPanEnd: isActive ? _onPanEnd : null,
      child: CustomPaint(
        painter: DrawingPainter(
          paths: widget.existingDrawings
              .where(
                (p) =>
                    p.pageNumber == widget.pageNumber &&
                    !_erasedDrawingIds.contains(p.id),
              )
              .toList(),
          currentPath: _currentPath,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.drawingMode == DrawingMode.draw) {
      setState(() {
        _currentPath = DrawingPath(
          filePath: widget.filePath,
          pageNumber: widget.pageNumber,
          points: [details.localPosition],
          color: widget.selectedColor,
          strokeWidth: widget.strokeWidth,
        );
      });
    } else if (widget.drawingMode == DrawingMode.erase) {
      _eraseAtPoint(details.localPosition);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.drawingMode == DrawingMode.draw && _currentPath != null) {
      setState(() {
        _currentPath = _currentPath!.copyWith(
          points: [..._currentPath!.points, details.localPosition],
        );
      });
    } else if (widget.drawingMode == DrawingMode.erase) {
      _eraseAtPoint(details.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.drawingMode == DrawingMode.draw) {
      if (_currentPath != null && _currentPath!.points.length > 1) {
        widget.onDrawingComplete(_currentPath!);
        setState(() {
          _currentPath = null;
        });
      }
    }
  }

  void _eraseAtPoint(Offset point) {
    final eraserRadiusSquared = widget.eraserRadius * widget.eraserRadius;

    for (final drawing in widget.existingDrawings) {
      if (drawing.pageNumber != widget.pageNumber) continue;
      if (_erasedDrawingIds.contains(drawing.id)) continue;

      // Check if any point in the drawing is within eraser radius
      for (final drawingPoint in drawing.points) {
        final dx = drawingPoint.dx - point.dx;
        final dy = drawingPoint.dy - point.dy;
        final distanceSquared = dx * dx + dy * dy;

        if (distanceSquared <= eraserRadiusSquared) {
          // Mark this drawing for erasure
          if (drawing.id != null) {
            setState(() {
              _erasedDrawingIds.add(drawing.id!);
            });
            widget.onDrawingErased?.call(drawing.id!);
          }
          break; // Move to next drawing
        }
      }
    }
  }
}
