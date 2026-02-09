import 'dart:convert';
import 'package:http/http.dart' as http;

/// Smart AI Features Service
/// Provides intelligent search and classification:
/// - Keyword smart search (exact paragraph highlight)
/// - Synonym search (agreement = contract)
/// - Document classification (Invoice/ID/Notes/Contract)
class SmartAiService {
  static const String _baseUrl = 'http://localhost:8000';

  /// Perform smart keyword search with exact paragraph highlighting
  /// Example: search "termination clause" → exact paragraph highlight
  Future<SmartSearchResult> smartSearch({
    required String pdfPath,
    required String query,
    bool includeSynonyms = true,
    bool highlightParagraphs = true,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ai/smart-search'),
      );

      request.files.add(await http.MultipartFile.fromPath('pdf', pdfPath));

      request.fields['query'] = query;
      request.fields['include_synonyms'] = includeSynonyms.toString();
      request.fields['highlight_paragraphs'] = highlightParagraphs.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SmartSearchResult.fromJson(data);
      } else {
        throw Exception('Smart search failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Smart search error: $e');
    }
  }

  /// Search with synonym expansion
  /// Example: "agreement" will also find "contract", "deal", etc.
  Future<SynonymSearchResult> synonymSearch({
    required String pdfPath,
    required String query,
    int maxSynonyms = 5,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ai/synonym-search'),
      );

      request.files.add(await http.MultipartFile.fromPath('pdf', pdfPath));

      request.fields['query'] = query;
      request.fields['max_synonyms'] = maxSynonyms.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SynonymSearchResult.fromJson(data);
      } else {
        throw Exception('Synonym search failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Synonym search error: $e');
    }
  }

  /// Classify document type automatically
  /// Returns: Invoice, ID, Notes, Contract, or Other
  Future<DocumentClassification> classifyDocument(String pdfPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ai/classify-document'),
      );

      request.files.add(await http.MultipartFile.fromPath('pdf', pdfPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DocumentClassification.fromJson(data);
      } else {
        throw Exception('Document classification failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Document classification error: $e');
    }
  }

  /// Get semantic similarity between two text segments
  Future<double> getSemanticSimilarity(String text1, String text2) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai/semantic-similarity'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text1': text1, 'text2': text2}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['similarity'] ?? 0.0).toDouble();
      } else {
        throw Exception('Semantic similarity failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Semantic similarity error: $e');
    }
  }

  /// Extract key phrases from document
  Future<List<KeyPhrase>> extractKeyPhrases(String pdfPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ai/extract-keyphrases'),
      );

      request.files.add(await http.MultipartFile.fromPath('pdf', pdfPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['keyphrases'] as List)
            .map((kp) => KeyPhrase.fromJson(kp))
            .toList();
      } else {
        throw Exception('Key phrase extraction failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Key phrase extraction error: $e');
    }
  }

  /// Get document topics using topic modeling
  Future<List<DocumentTopic>> getDocumentTopics(String pdfPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ai/extract-topics'),
      );

      request.files.add(await http.MultipartFile.fromPath('pdf', pdfPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['topics'] as List)
            .map((t) => DocumentTopic.fromJson(t))
            .toList();
      } else {
        throw Exception('Topic extraction failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Topic extraction error: $e');
    }
  }

  /// Check if AI service is available
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

/// Smart Search Result
class SmartSearchResult {
  final String query;
  final List<SearchMatch> matches;
  final int totalMatches;
  final List<String> synonymsUsed;
  final Map<String, dynamic>? metadata;

  SmartSearchResult({
    required this.query,
    required this.matches,
    required this.totalMatches,
    required this.synonymsUsed,
    this.metadata,
  });

  factory SmartSearchResult.fromJson(Map<String, dynamic> json) {
    return SmartSearchResult(
      query: json['query'] ?? '',
      matches: (json['matches'] as List)
          .map((m) => SearchMatch.fromJson(m))
          .toList(),
      totalMatches: json['total_matches'] ?? 0,
      synonymsUsed: List<String>.from(json['synonyms_used'] ?? []),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'matches': matches.map((m) => m.toJson()).toList(),
      'total_matches': totalMatches,
      'synonyms_used': synonymsUsed,
      'metadata': metadata,
    };
  }
}

/// Search Match
class SearchMatch {
  final int pageNumber;
  final String paragraph;
  final String matchedText;
  final double relevanceScore;
  final int startIndex;
  final int endIndex;
  final String matchType; // 'exact', 'synonym', 'semantic'

  SearchMatch({
    required this.pageNumber,
    required this.paragraph,
    required this.matchedText,
    required this.relevanceScore,
    required this.startIndex,
    required this.endIndex,
    required this.matchType,
  });

  factory SearchMatch.fromJson(Map<String, dynamic> json) {
    return SearchMatch(
      pageNumber: json['page_number'] ?? 0,
      paragraph: json['paragraph'] ?? '',
      matchedText: json['matched_text'] ?? '',
      relevanceScore: (json['relevance_score'] ?? 0.0).toDouble(),
      startIndex: json['start_index'] ?? 0,
      endIndex: json['end_index'] ?? 0,
      matchType: json['match_type'] ?? 'exact',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page_number': pageNumber,
      'paragraph': paragraph,
      'matched_text': matchedText,
      'relevance_score': relevanceScore,
      'start_index': startIndex,
      'end_index': endIndex,
      'match_type': matchType,
    };
  }
}

/// Synonym Search Result
class SynonymSearchResult {
  final String originalQuery;
  final List<String> synonyms;
  final List<SearchMatch> matches;
  final int totalMatches;

  SynonymSearchResult({
    required this.originalQuery,
    required this.synonyms,
    required this.matches,
    required this.totalMatches,
  });

  factory SynonymSearchResult.fromJson(Map<String, dynamic> json) {
    return SynonymSearchResult(
      originalQuery: json['original_query'] ?? '',
      synonyms: List<String>.from(json['synonyms'] ?? []),
      matches: (json['matches'] as List)
          .map((m) => SearchMatch.fromJson(m))
          .toList(),
      totalMatches: json['total_matches'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'original_query': originalQuery,
      'synonyms': synonyms,
      'matches': matches.map((m) => m.toJson()).toList(),
      'total_matches': totalMatches,
    };
  }
}

/// Document Classification
class DocumentClassification {
  final String documentType;
  final double confidence;
  final List<ClassificationCandidate> candidates;
  final Map<String, dynamic> features;

  DocumentClassification({
    required this.documentType,
    required this.confidence,
    required this.candidates,
    required this.features,
  });

  factory DocumentClassification.fromJson(Map<String, dynamic> json) {
    return DocumentClassification(
      documentType: json['document_type'] ?? 'Other',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      candidates: (json['candidates'] as List)
          .map((c) => ClassificationCandidate.fromJson(c))
          .toList(),
      features: json['features'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'document_type': documentType,
      'confidence': confidence,
      'candidates': candidates.map((c) => c.toJson()).toList(),
      'features': features,
    };
  }
}

/// Classification Candidate
class ClassificationCandidate {
  final String type;
  final double confidence;

  ClassificationCandidate({required this.type, required this.confidence});

  factory ClassificationCandidate.fromJson(Map<String, dynamic> json) {
    return ClassificationCandidate(
      type: json['type'] ?? 'Other',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'confidence': confidence};
  }
}

/// Key Phrase
class KeyPhrase {
  final String phrase;
  final double score;
  final int frequency;

  KeyPhrase({
    required this.phrase,
    required this.score,
    required this.frequency,
  });

  factory KeyPhrase.fromJson(Map<String, dynamic> json) {
    return KeyPhrase(
      phrase: json['phrase'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      frequency: json['frequency'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'phrase': phrase, 'score': score, 'frequency': frequency};
  }
}

/// Document Topic
class DocumentTopic {
  final String topic;
  final double weight;
  final List<String> keywords;

  DocumentTopic({
    required this.topic,
    required this.weight,
    required this.keywords,
  });

  factory DocumentTopic.fromJson(Map<String, dynamic> json) {
    return DocumentTopic(
      topic: json['topic'] ?? '',
      weight: (json['weight'] ?? 0.0).toDouble(),
      keywords: List<String>.from(json['keywords'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {'topic': topic, 'weight': weight, 'keywords': keywords};
  }
}
