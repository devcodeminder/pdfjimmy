import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// OCR Engine Service
/// Provides offline OCR capabilities using Tesseract via Python backend:
/// - Offline OCR
/// - Language auto-detection
/// - Handwriting recognition (premium)
/// - Layout-aware OCR (tables, columns)
class OcrEngineService {
  static const String _baseUrl = 'http://localhost:8000';

  /// Perform OCR on an image
  Future<OcrResult> performOcr(
    Uint8List imageBytes, {
    String? language,
    bool detectLanguage = true,
    bool preserveLayout = true,
  }) async {
    try {
      // Save image temporarily
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, 'ocr_temp.png'));
      await tempFile.writeAsBytes(imageBytes);

      // Prepare request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ocr/extract'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', tempFile.path),
      );

      request.fields['detect_language'] = detectLanguage.toString();
      request.fields['preserve_layout'] = preserveLayout.toString();
      if (language != null) {
        request.fields['language'] = language;
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Clean up temp file
      await tempFile.delete();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OcrResult.fromJson(data);
      } else {
        throw Exception('OCR failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('OCR error: $e');
    }
  }

  /// Perform OCR on a PDF page
  Future<OcrResult> performPdfPageOcr(
    String pdfPath,
    int pageNumber, {
    String? language,
    bool detectLanguage = true,
    bool preserveLayout = true,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ocr/pdf-page'),
      );

      request.files.add(await http.MultipartFile.fromPath('pdf', pdfPath));

      request.fields['page_number'] = pageNumber.toString();
      request.fields['detect_language'] = detectLanguage.toString();
      request.fields['preserve_layout'] = preserveLayout.toString();
      if (language != null) {
        request.fields['language'] = language;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OcrResult.fromJson(data);
      } else {
        throw Exception('PDF OCR failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('PDF OCR error: $e');
    }
  }

  /// Perform handwriting recognition (premium feature)
  Future<OcrResult> recognizeHandwriting(
    Uint8List imageBytes, {
    String? language,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, 'handwriting_temp.png'));
      await tempFile.writeAsBytes(imageBytes);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ocr/handwriting'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', tempFile.path),
      );

      if (language != null) {
        request.fields['language'] = language;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      await tempFile.delete();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OcrResult.fromJson(data);
      } else {
        throw Exception('Handwriting recognition failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Handwriting recognition error: $e');
    }
  }

  /// Extract tables from document using layout-aware OCR
  Future<TableExtractionResult> extractTables(
    Uint8List imageBytes, {
    String? language,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, 'table_temp.png'));
      await tempFile.writeAsBytes(imageBytes);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ocr/extract-tables'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', tempFile.path),
      );

      if (language != null) {
        request.fields['language'] = language;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      await tempFile.delete();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TableExtractionResult.fromJson(data);
      } else {
        throw Exception('Table extraction failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Table extraction error: $e');
    }
  }

  /// Detect language of text in image
  Future<LanguageDetectionResult> detectLanguage(Uint8List imageBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, 'lang_detect_temp.png'));
      await tempFile.writeAsBytes(imageBytes);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ocr/detect-language'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', tempFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      await tempFile.delete();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LanguageDetectionResult.fromJson(data);
      } else {
        throw Exception('Language detection failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Language detection error: $e');
    }
  }

  /// Get list of supported languages
  Future<List<String>> getSupportedLanguages() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ocr/languages'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['languages']);
      } else {
        throw Exception('Failed to get supported languages');
      }
    } catch (e) {
      throw Exception('Error getting supported languages: $e');
    }
  }

  /// Check if OCR service is available
  Future<bool> isServiceAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// OCR Result model
class OcrResult {
  final String text;
  final String? detectedLanguage;
  final double confidence;
  final List<OcrBlock>? blocks;
  final Map<String, dynamic>? metadata;

  OcrResult({
    required this.text,
    this.detectedLanguage,
    required this.confidence,
    this.blocks,
    this.metadata,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      text: json['text'] ?? '',
      detectedLanguage: json['detected_language'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      blocks: json['blocks'] != null
          ? (json['blocks'] as List).map((b) => OcrBlock.fromJson(b)).toList()
          : null,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'detected_language': detectedLanguage,
      'confidence': confidence,
      'blocks': blocks?.map((b) => b.toJson()).toList(),
      'metadata': metadata,
    };
  }
}

/// OCR Block (for layout-aware OCR)
class OcrBlock {
  final String text;
  final double confidence;
  final BoundingBox boundingBox;
  final String type; // 'paragraph', 'line', 'word', 'table', 'column'

  OcrBlock({
    required this.text,
    required this.confidence,
    required this.boundingBox,
    required this.type,
  });

  factory OcrBlock.fromJson(Map<String, dynamic> json) {
    return OcrBlock(
      text: json['text'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      boundingBox: BoundingBox.fromJson(json['bounding_box']),
      type: json['type'] ?? 'paragraph',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'bounding_box': boundingBox.toJson(),
      'type': type,
    };
  }
}

/// Bounding Box for OCR blocks
class BoundingBox {
  final int x;
  final int y;
  final int width;
  final int height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'width': width, 'height': height};
  }
}

/// Table Extraction Result
class TableExtractionResult {
  final List<TableData> tables;
  final int tableCount;

  TableExtractionResult({required this.tables, required this.tableCount});

  factory TableExtractionResult.fromJson(Map<String, dynamic> json) {
    return TableExtractionResult(
      tables: (json['tables'] as List)
          .map((t) => TableData.fromJson(t))
          .toList(),
      tableCount: json['table_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tables': tables.map((t) => t.toJson()).toList(),
      'table_count': tableCount,
    };
  }
}

/// Table Data
class TableData {
  final List<List<String>> rows;
  final int rowCount;
  final int columnCount;
  final BoundingBox boundingBox;

  TableData({
    required this.rows,
    required this.rowCount,
    required this.columnCount,
    required this.boundingBox,
  });

  factory TableData.fromJson(Map<String, dynamic> json) {
    return TableData(
      rows: (json['rows'] as List)
          .map((row) => List<String>.from(row))
          .toList(),
      rowCount: json['row_count'] ?? 0,
      columnCount: json['column_count'] ?? 0,
      boundingBox: BoundingBox.fromJson(json['bounding_box']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rows': rows,
      'row_count': rowCount,
      'column_count': columnCount,
      'bounding_box': boundingBox.toJson(),
    };
  }
}

/// Language Detection Result
class LanguageDetectionResult {
  final String primaryLanguage;
  final double confidence;
  final List<LanguageCandidate> candidates;

  LanguageDetectionResult({
    required this.primaryLanguage,
    required this.confidence,
    required this.candidates,
  });

  factory LanguageDetectionResult.fromJson(Map<String, dynamic> json) {
    return LanguageDetectionResult(
      primaryLanguage: json['primary_language'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      candidates:
          (json['candidates'] as List?)
              ?.map((c) => LanguageCandidate.fromJson(c))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_language': primaryLanguage,
      'confidence': confidence,
      'candidates': candidates.map((c) => c.toJson()).toList(),
    };
  }
}

/// Language Candidate
class LanguageCandidate {
  final String language;
  final double confidence;

  LanguageCandidate({required this.language, required this.confidence});

  factory LanguageCandidate.fromJson(Map<String, dynamic> json) {
    return LanguageCandidate(
      language: json['language'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'language': language, 'confidence': confidence};
  }
}
