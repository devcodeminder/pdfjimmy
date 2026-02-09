import 'dart:convert';
import 'package:flutter/material.dart';

/// Represents a single drawing path on a PDF page
class DrawingPath {
  final int? id;
  final String filePath;
  final int pageNumber;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DateTime createdAt;

  DrawingPath({
    this.id,
    required this.filePath,
    required this.pageNumber,
    required this.points,
    required this.color,
    required this.strokeWidth,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'pathData': jsonEncode(
        points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      ),
      'color': color.value,
      'strokeWidth': strokeWidth,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from database map
  factory DrawingPath.fromMap(Map<String, dynamic> map) {
    final pathData = jsonDecode(map['pathData']) as List;
    final points = pathData
        .map((p) => Offset(p['x'] as double, p['y'] as double))
        .toList();

    return DrawingPath(
      id: map['id'] as int?,
      filePath: map['filePath'] as String,
      pageNumber: map['pageNumber'] as int,
      points: points,
      color: Color(map['color'] as int),
      strokeWidth: map['strokeWidth'] as double,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  /// Create a copy with updated fields
  DrawingPath copyWith({
    int? id,
    String? filePath,
    int? pageNumber,
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    DateTime? createdAt,
  }) {
    return DrawingPath(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Drawing tool mode
enum DrawingMode { none, draw, erase }

/// Predefined drawing colors
class DrawingColors {
  static const Color black = Colors.black;
  static const Color red = Colors.red;
  static const Color blue = Colors.blue;
  static const Color green = Colors.green;
  static const Color yellow = Colors.yellow;
  static const Color orange = Colors.orange;
  static const Color purple = Colors.purple;
  static const Color pink = Colors.pink;
  static const Color white = Colors.white;

  static const List<Color> all = [
    black,
    red,
    blue,
    green,
    yellow,
    orange,
    purple,
    pink,
    white,
  ];
}

/// Predefined stroke widths
class StrokeWidths {
  static const double thin = 2.0;
  static const double medium = 4.0;
  static const double thick = 6.0;
  static const double extraThick = 8.0;

  static const List<double> all = [thin, medium, thick, extraThick];
}
