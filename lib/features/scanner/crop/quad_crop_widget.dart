import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuadCropWidget extends StatefulWidget {
  final ui.Image image;
  final List<Offset> initialPoints;
  final ValueChanged<List<Offset>> onPointsChanged;

  const QuadCropWidget({
    super.key,
    required this.image,
    required this.initialPoints,
    required this.onPointsChanged,
  });

  @override
  State<QuadCropWidget> createState() => _QuadCropWidgetState();
}

class _QuadCropWidgetState extends State<QuadCropWidget> {
  late List<Offset> points;
  int? draggingIndex;
  Offset? _magnifierPosition;
  Offset? _magnifyFocus;

  @override
  void initState() {
    super.initState();
    points = List.from(widget.initialPoints);
    if (points.isEmpty) {
      points = [
        const Offset(0.0, 0.0),
        const Offset(1.0, 0.0),
        const Offset(1.0, 1.0),
        const Offset(0.0, 1.0),
      ];
    }
  }

  @override
  void didUpdateWidget(covariant QuadCropWidget oldWidget) {
    if (widget.initialPoints != oldWidget.initialPoints &&
        widget.initialPoints.isNotEmpty) {
      points = List.from(widget.initialPoints);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imgSize = Size(
          widget.image.width.toDouble(),
          widget.image.height.toDouble(),
        );
        final fit = _calculateBoxFit(imgSize, viewSize);
        final rect = _calculateFittedRect(imgSize, fit, viewSize);

        void updatePoint(Offset localPos) {
          if (draggingIndex == null) return;
          // Constrain point within the image rect
          final x = localPos.dx.clamp(rect.left, rect.right);
          final y = localPos.dy.clamp(rect.top, rect.bottom);

          final nx = (x - rect.left) / rect.width;
          final ny = (y - rect.top) / rect.height;

          setState(() {
            points[draggingIndex!] = Offset(nx, ny);
            _magnifierPosition = Offset(x, y);

            // For the magnifier, we focus on the raw position.
            // RawMagnifier will magnify the screen around _magnifyFocus
            RenderBox box = context.findRenderObject() as RenderBox;
            _magnifyFocus = box.localToGlobal(Offset(x, y));
          });
          widget.onPointsChanged(points);
        }

        return Stack(
          children: [
            Center(
              child: GestureDetector(
                onPanStart: (details) {
                  final hitPoint = _findClosestPoint(
                    details.localPosition,
                    rect,
                  );
                  if (hitPoint != null) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      draggingIndex = hitPoint;
                      updatePoint(details.localPosition);
                    });
                  }
                },
                onPanUpdate: (details) {
                  updatePoint(details.localPosition);
                },
                onPanEnd: (_) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    draggingIndex = null;
                    _magnifierPosition = null;
                    _magnifyFocus = null;
                  });
                },
                onPanCancel: () {
                  setState(() {
                    draggingIndex = null;
                    _magnifierPosition = null;
                    _magnifyFocus = null;
                  });
                },
                child: CustomPaint(
                  size: Size(double.infinity, double.infinity),
                  painter: _QuadCropPainter(
                    image: widget.image,
                    points: points,
                    rect: rect,
                    draggingIndex: draggingIndex,
                  ),
                ),
              ),
            ),

            if (_magnifierPosition != null && _magnifyFocus != null)
              Builder(
                builder: (context) {
                  // Calculate position only when magnifier is visible
                  final double magWidth = 120;
                  final double magHeight = 120;
                  final double magVerticalOffset = 160;

                  final double magLeft = (_magnifierPosition!.dx - magWidth / 2)
                      .clamp(0, viewSize.width - magWidth);
                  final double magTop =
                      (_magnifierPosition!.dy - magVerticalOffset).clamp(
                        0,
                        viewSize.height - magHeight,
                      );

                  final focalOffset =
                      _magnifierPosition! -
                      Offset(magLeft + magWidth / 2, magTop + magHeight / 2);

                  return Positioned(
                    left: magLeft,
                    top: magTop,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RawMagnifier(
                          decoration: const MagnifierDecoration(
                            shape: CircleBorder(
                              side: BorderSide(color: Colors.white, width: 2),
                            ),
                            shadows: [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          size: Size(magWidth, magHeight),
                          magnificationScale: 1.5,
                          focalPointOffset: focalOffset,
                        ),
                        // Center target point (Sharp Crosshair)
                        CustomPaint(
                          size: const Size(20, 20),
                          painter: _TargetCrosshairPainter(),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  int? _findClosestPoint(Offset localPos, Rect rect) {
    double minD = double.infinity;
    int? closest;
    for (int i = 0; i < points.length; i++) {
      final p = Offset(
        rect.left + points[i].dx * rect.width,
        rect.top + points[i].dy * rect.height,
      );
      final d = (p - localPos).distance;
      if (d < 60 && d < minD) {
        minD = d;
        closest = i;
      }
    }
    return closest;
  }

  BoxFit _calculateBoxFit(Size imgSize, Size viewSize) {
    if (imgSize.width / imgSize.height > viewSize.width / viewSize.height) {
      return BoxFit.fitWidth;
    }
    return BoxFit.fitHeight;
  }

  Rect _calculateFittedRect(Size imgSize, BoxFit fit, Size viewSize) {
    final double srcWidth = imgSize.width;
    final double srcHeight = imgSize.height;
    double dstWidth = viewSize.width;
    double dstHeight = viewSize.height;

    if (fit == BoxFit.fitWidth ||
        (fit == BoxFit.contain &&
            srcWidth / srcHeight > dstWidth / dstHeight)) {
      dstHeight = dstWidth * srcHeight / srcWidth;
    } else {
      dstWidth = dstHeight * srcWidth / srcHeight;
    }

    final double dstLeft = (viewSize.width - dstWidth) / 2;
    final double dstTop = (viewSize.height - dstHeight) / 2;

    return Rect.fromLTWH(dstLeft, dstTop, dstWidth, dstHeight);
  }
}

class _QuadCropPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> points;
  final Rect rect;
  final int? draggingIndex;

  _QuadCropPainter({
    required this.image,
    required this.points,
    required this.rect,
    this.draggingIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw image
    paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.fill);

    // 2. Draw mask over everything outside polygon
    final path = Path();
    final p0 = _getActual(points[0]);
    final p1 = _getActual(points[1]);
    final p2 = _getActual(points[2]);
    final p3 = _getActual(points[3]);

    path.moveTo(p0.dx, p0.dy);
    path.lineTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);
    path.close();

    final fullPath = Path()..addRect(rect);
    final maskPath = Path.combine(PathOperation.difference, fullPath, path);
    canvas.drawPath(maskPath, Paint()..color = Colors.black54);

    // 3. Draw connecting lines
    final linePaint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // 4. Draw corners
    for (int i = 0; i < points.length; i++) {
      if (i == draggingIndex)
        continue; // Hide active dot so it doesn't obscure the magnifier
      final p = _getActual(points[i]);
      _drawNeonDot(canvas, p);
    }
  }

  void _drawNeonDot(Canvas canvas, Offset p) {
    canvas.drawCircle(p, 12, Paint()..color = Colors.white);
    canvas.drawCircle(
      p,
      12,
      Paint()
        ..color = const Color(0xFF00F5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  Offset _getActual(Offset p) {
    return Offset(rect.left + p.dx * rect.width, rect.top + p.dy * rect.height);
  }

  @override
  bool shouldRepaint(covariant _QuadCropPainter oldDelegate) {
    return true; // Simple repaint always
  }
}

class _TargetCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Add a very subtle dark outline for contrast against light images
    final bgPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final fgPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final double l = 8.0;

    // Draw dark background lines
    canvas.drawLine(
      Offset(center.dx - l, center.dy),
      Offset(center.dx + l, center.dy),
      bgPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - l),
      Offset(center.dx, center.dy + l),
      bgPaint,
    );

    // Draw bright green foreground lines
    canvas.drawLine(
      Offset(center.dx - l, center.dy),
      Offset(center.dx + l, center.dy),
      fgPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - l),
      Offset(center.dx, center.dy + l),
      fgPaint,
    );

    // Draw pure center dot
    canvas.drawCircle(center, 1.5, Paint()..color = Colors.greenAccent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
