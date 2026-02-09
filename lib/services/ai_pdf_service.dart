import 'dart:convert';
import 'package:http/http.dart' as http;

/// AI-powered PDF analysis service
/// Connects to Python backend for advanced AI features
class AIPdfService {
  // Using actual PC IP address - make sure PC and device are on same network
  // If this doesn't work, try: 10.0.2.2 (Android Emulator) or localhost (desktop)
  static const String _baseUrl = 'http://192.168.0.103:8002';

  /// Check if AI service is running
  static Future<bool> isServiceRunning() async {
    try {
      print('Attempting to connect to: $_baseUrl/health');
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      print('Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  /// Get full PDF analysis with all features
  static Future<Map<String, dynamic>> analyzeFullPdf(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/analyze/full'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Analysis failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to analyze PDF: $e');
    }
  }

  /// Get 5-bullet summary of entire PDF
  static Future<List<String>> getSummaryBullets(
    String filePath, {
    int numPoints = 5,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/analyze/summary'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['num_points'] = numPoints.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['summary_bullets']);
      } else {
        throw Exception('Summary failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get summary: $e');
    }
  }

  /// Get page-wise summaries
  static Future<List<Map<String, dynamic>>> getPageSummaries(
    String filePath,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/analyze/page-summaries'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['page_summaries']);
      } else {
        throw Exception('Page summaries failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get page summaries: $e');
    }
  }

  /// Detect important lines in PDF
  static Future<List<Map<String, dynamic>>> getImportantLines(
    String filePath, {
    int topN = 10,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/analyze/important-lines'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['top_n'] = topN.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['important_lines']);
      } else {
        throw Exception('Important lines detection failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to detect important lines: $e');
    }
  }

  /// Detect entities (dates, amounts, definitions, etc.)
  static Future<Map<String, List<String>>> detectEntities(
    String filePath,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/analyze/entities'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final entities = data['entities'] as Map<String, dynamic>;

        return entities.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        );
      } else {
        throw Exception('Entity detection failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to detect entities: $e');
    }
  }

  /// Get categorized highlights (definitions, dates, amounts)
  static Future<Map<String, List<Map<String, dynamic>>>>
  getCategorizedHighlights(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/analyze/categorize-highlights'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final highlights = data['highlights'] as Map<String, dynamic>;

        return highlights.map(
          (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)),
        );
      } else {
        throw Exception('Highlight categorization failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to categorize highlights: $e');
    }
  }

  /// Translate text to target language
  static Future<String> translateText(
    String text, {
    String targetLang = 'hi', // Hindi by default
    String sourceLang = 'auto',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/translate/text'),
        body: {
          'text': text,
          'target_lang': targetLang,
          'source_lang': sourceLang,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['translated'];
      } else {
        throw Exception('Translation failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to translate text: $e');
    }
  }

  /// Translate entire PDF
  static Future<String> translatePdf(
    String filePath, {
    String targetLang = 'hi',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/translate/pdf'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['target_lang'] = targetLang;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['translated_text'];
      } else {
        throw Exception('PDF translation failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to translate PDF: $e');
    }
  }

  /// Translate page with layout preservation
  static Future<Map<String, dynamic>> translatePageWithLayout(
    String filePath,
    int pageNum, {
    String targetLang = 'hi',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/translate/page-layout'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['page_num'] = pageNum.toString();
      request.fields['target_lang'] = targetLang;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Page translation failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to translate page: $e');
    }
  }

  /// Get supported language codes
  static Map<String, String> getSupportedLanguages() {
    return {
      'en': 'English',
      'hi': 'Hindi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'gu': 'Gujarati',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'pa': 'Punjabi',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
      'ru': 'Russian',
    };
  }
}
