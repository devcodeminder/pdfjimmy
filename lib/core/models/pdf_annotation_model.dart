import 'package:flutter/material.dart';

// Model for text highlights
class TextHighlight {
  final int? id;
  final String filePath;
  final int pageNumber;
  final String text;
  final Color color;
  final DateTime createdAt;

  TextHighlight({
    this.id,
    required this.filePath,
    required this.pageNumber,
    required this.text,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'text': text,
      'color': color.value,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TextHighlight.fromMap(Map<String, dynamic> map) {
    return TextHighlight(
      id: map['id'],
      filePath: map['filePath'],
      pageNumber: map['pageNumber'],
      text: map['text'],
      color: Color(map['color']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  TextHighlight copyWith({
    int? id,
    String? filePath,
    int? pageNumber,
    String? text,
    Color? color,
    DateTime? createdAt,
  }) {
    return TextHighlight(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Model for underlined text
class TextUnderline {
  final int? id;
  final String filePath;
  final int pageNumber;
  final String text;
  final DateTime createdAt;

  TextUnderline({
    this.id,
    required this.filePath,
    required this.pageNumber,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TextUnderline.fromMap(Map<String, dynamic> map) {
    return TextUnderline(
      id: map['id'],
      filePath: map['filePath'],
      pageNumber: map['pageNumber'],
      text: map['text'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  TextUnderline copyWith({
    int? id,
    String? filePath,
    int? pageNumber,
    String? text,
    DateTime? createdAt,
  }) {
    return TextUnderline(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Model for strikethrough text
class TextStrikethrough {
  final int? id;
  final String filePath;
  final int pageNumber;
  final String text;
  final DateTime createdAt;

  TextStrikethrough({
    this.id,
    required this.filePath,
    required this.pageNumber,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TextStrikethrough.fromMap(Map<String, dynamic> map) {
    return TextStrikethrough(
      id: map['id'],
      filePath: map['filePath'],
      pageNumber: map['pageNumber'],
      text: map['text'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  TextStrikethrough copyWith({
    int? id,
    String? filePath,
    int? pageNumber,
    String? text,
    DateTime? createdAt,
  }) {
    return TextStrikethrough(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Model for squiggly text
class TextSquiggly {
  final int? id;
  final String filePath;
  final int pageNumber;
  final String text;
  final DateTime createdAt;

  TextSquiggly({
    this.id,
    required this.filePath,
    required this.pageNumber,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TextSquiggly.fromMap(Map<String, dynamic> map) {
    return TextSquiggly(
      id: map['id'],
      filePath: map['filePath'],
      pageNumber: map['pageNumber'],
      text: map['text'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  TextSquiggly copyWith({
    int? id,
    String? filePath,
    int? pageNumber,
    String? text,
    DateTime? createdAt,
  }) {
    return TextSquiggly(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Model for notes/comments
class PdfNote {
  final int? id;
  final String filePath;
  final int pageNumber;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PdfNote({
    this.id,
    required this.filePath,
    required this.pageNumber,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'title': title,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory PdfNote.fromMap(Map<String, dynamic> map) {
    return PdfNote(
      id: map['id'],
      filePath: map['filePath'],
      pageNumber: map['pageNumber'],
      title: map['title'],
      content: map['content'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  PdfNote copyWith({
    int? id,
    String? filePath,
    int? pageNumber,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PdfNote(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Enum for PDF view mode
enum PdfViewMode { continuous, single }

// Enum for PDF fit mode
enum PdfFitMode { fitWidth, fitPage, custom }

// Enum for PDF rotation
enum PdfRotation { rotate0, rotate90, rotate180, rotate270 }

extension PdfRotationExtension on PdfRotation {
  int get degrees {
    switch (this) {
      case PdfRotation.rotate0:
        return 0;
      case PdfRotation.rotate90:
        return 90;
      case PdfRotation.rotate180:
        return 180;
      case PdfRotation.rotate270:
        return 270;
    }
  }

  PdfRotation get next {
    switch (this) {
      case PdfRotation.rotate0:
        return PdfRotation.rotate90;
      case PdfRotation.rotate90:
        return PdfRotation.rotate180;
      case PdfRotation.rotate180:
        return PdfRotation.rotate270;
      case PdfRotation.rotate270:
        return PdfRotation.rotate0;
    }
  }
}
