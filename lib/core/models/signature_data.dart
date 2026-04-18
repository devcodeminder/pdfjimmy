import 'dart:typed_data';
import 'package:flutter/material.dart';

enum SignatureType {
  drawn, // Hand-drawn signature
  image, // Imported from camera/gallery
  template, // Generated from template
  text, // Text-based signature
}

class SignatureData {
  final String id;
  final String name;
  final Uint8List imageData;
  final DateTime createdAt;

  // Advanced features
  final Color strokeColor;
  final double strokeWidth;
  final SignatureType type;
  final String? templateId;
  final double rotation; // 0-360 degrees
  final bool isVerified;
  final bool isFavorite;
  final int usageCount;
  final Map<String, dynamic>? metadata;

  SignatureData({
    required this.id,
    required this.name,
    required this.imageData,
    required this.createdAt,
    this.strokeColor = Colors.black,
    this.strokeWidth = 3.0,
    this.type = SignatureType.image,
    this.templateId,
    this.rotation = 0.0,
    this.isVerified = false,
    this.isFavorite = false,
    this.usageCount = 0,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageData': imageData.toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'strokeColor': strokeColor.toARGB32(),
      'strokeWidth': strokeWidth,
      'type': type.toString(),
      'templateId': templateId,
      'rotation': rotation,
      'isVerified': isVerified,
      'isFavorite': isFavorite,
      'usageCount': usageCount,
      'metadata': metadata,
    };
  }

  factory SignatureData.fromJson(Map<String, dynamic> json) {
    return SignatureData(
      id: json['id'] as String,
      name: json['name'] as String,
      imageData: Uint8List.fromList((json['imageData'] as List).cast<int>()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      strokeColor: Color(
        json['strokeColor'] as int? ?? Colors.black.toARGB32(),
      ),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      type: _parseSignatureType(json['type'] as String?),
      templateId: json['templateId'] as String?,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['isVerified'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      usageCount: json['usageCount'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static SignatureType _parseSignatureType(String? typeString) {
    if (typeString == null) return SignatureType.image;
    return SignatureType.values.firstWhere(
      (e) => e.toString() == typeString,
      orElse: () => SignatureType.image,
    );
  }

  SignatureData copyWith({
    String? id,
    String? name,
    Uint8List? imageData,
    DateTime? createdAt,
    Color? strokeColor,
    double? strokeWidth,
    SignatureType? type,
    String? templateId,
    double? rotation,
    bool? isVerified,
    bool? isFavorite,
    int? usageCount,
    Map<String, dynamic>? metadata,
  }) {
    return SignatureData(
      id: id ?? this.id,
      name: name ?? this.name,
      imageData: imageData ?? this.imageData,
      createdAt: createdAt ?? this.createdAt,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      type: type ?? this.type,
      templateId: templateId ?? this.templateId,
      rotation: rotation ?? this.rotation,
      isVerified: isVerified ?? this.isVerified,
      isFavorite: isFavorite ?? this.isFavorite,
      usageCount: usageCount ?? this.usageCount,
      metadata: metadata ?? this.metadata,
    );
  }
}

class SignaturePosition {
  double x;
  double y;
  double scale;
  int pageNumber;
  String signatureId;
  double rotation; // Added rotation support

  SignaturePosition({
    this.x = 100,
    this.y = 100,
    this.scale = 1.0,
    required this.pageNumber,
    required this.signatureId,
    this.rotation = 0.0,
  });

  SignaturePosition copyWith({
    double? x,
    double? y,
    double? scale,
    int? pageNumber,
    String? signatureId,
    double? rotation,
  }) {
    return SignaturePosition(
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      pageNumber: pageNumber ?? this.pageNumber,
      signatureId: signatureId ?? this.signatureId,
      rotation: rotation ?? this.rotation,
    );
  }
}
