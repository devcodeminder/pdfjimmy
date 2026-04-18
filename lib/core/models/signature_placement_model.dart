import 'package:flutter/material.dart';

/// Represents a signature placed on a PDF page
class SignaturePlacement {
  final int? id;
  final String filePath;
  final int pageNumber;
  final String signatureId;
  final Offset position;
  final double scale;
  final double rotation;
  final DateTime createdAt;

  SignaturePlacement({
    this.id,
    required this.filePath,
    required this.pageNumber,
    required this.signatureId,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'signatureId': signatureId,
      'positionX': position.dx,
      'positionY': position.dy,
      'scale': scale,
      'rotation': rotation,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from database map
  factory SignaturePlacement.fromMap(Map<String, dynamic> map) {
    return SignaturePlacement(
      id: map['id'] as int?,
      filePath: map['filePath'] as String,
      pageNumber: map['pageNumber'] as int,
      signatureId: map['signatureId'] as String,
      position: Offset(map['positionX'] as double, map['positionY'] as double),
      scale: map['scale'] as double,
      rotation: map['rotation'] as double,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  /// Create a copy with updated fields
  SignaturePlacement copyWith({
    int? id,
    String? filePath,
    int? pageNumber,
    String? signatureId,
    Offset? position,
    double? scale,
    double? rotation,
    DateTime? createdAt,
  }) {
    return SignaturePlacement(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      signatureId: signatureId ?? this.signatureId,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
