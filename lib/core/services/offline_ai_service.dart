import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OfflineAiService {
  // Pure Dart implementation - No External Server Required
  // Works 100% Offline on Android/iOS/Windows for Play Store

  Future<Map<String, dynamic>> analyzePdf(String filePath) async {
    try {
      final text = await extractText(filePath);
      final summary = _generateSummary(text); // Local Dart Algorithm

      return {
        'text_length': text.length,
        'summary': summary,
        'full_text': text,
      };
    } catch (e) {
      throw Exception('Analysis Failed: $e');
    }
  }

  Future<String> extractText(String filePath) async {
    try {
      // Load the existing PDF document
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Extract text from all pages
      String extractedText = '';
      if (document.pages.count > 0) {
        extractedText = PdfTextExtractor(document).extractText();
      }

      document.dispose();

      // Clean up text artifacts (Fix encoding glitches)
      extractedText = _applyHeuristicFixes(extractedText);

      // Fix visual ordering for Tamil (Swap Pre-base Vowels)
      extractedText = _fixTamilVisualOrder(extractedText);

      return extractedText.trim();
    } catch (e) {
      // Fallback for empty or complex PDFs
      return '';
    }
  }

  // 🛠️ Advanced Tamil Text Repair for Broken PDFs
  String _applyHeuristicFixes(String text) {
    if (text.isEmpty) return text;

    // 1. Dictionary-based repairs for common words seen in the PDF
    final repairs = {
      'குறிப்H': 'குறிப்பு',
      'துHரை': 'துரை',
      'திH': 'திரு',
      'சுHக்க': 'சுருக்க', // Surukkam (Summary)
      'ஆண்A': 'ஆண்டு',
      'பன்A': 'பண்டு',
      'தெA': 'தெடு', // Thedu (?)
      'ஒH': 'ஒரு',
      'இருH': 'இரும்',
      'செH': 'செரு',
      'பெH': 'பெரு',
      'சH': 'சரு',
      'ப்H': 'ப்பு', // Kurippu exception
      'ட்H': 'ட்டு',
      'த்H': 'த்து',
      'க்H': 'க்கு',
    };

    repairs.forEach((broken, fixed) {
      text = text.replaceAll(broken, fixed);
    });

    // 2. Fallbacks for remaining artifacts
    // Replace 'A' with 'டு' (Du) - strictly whenever it follows a Tamil char
    text = text.replaceAllMapped(
      RegExp(r'([\u0B80-\u0BFF])A'),
      (Match m) => '${m.group(1)}\u0B9F\u0BC1',
    );

    // Replace remaining 'H' with 'ரு' (Ru) as it is the most common mapping
    text = text.replaceAllMapped(
      RegExp(r'([\u0B80-\u0BFF])H'),
      (Match m) => '${m.group(1)}\u0BB0\u0BC1',
    );

    // 3. Remove Dotted Circles (◌) - These are rendering failures
    text = text.replaceAll('\u25CC', '');

    // 4. Clean up spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text;
  }

  // 🛠️ Tamil Unicode Fixer (Visual to Logical)
  String _fixTamilVisualOrder(String text) {
    if (text.isEmpty) return text;
    // Range: \u0BC6 (e), \u0BC7 (E), \u0BC8 (ai)
    final visualVowels = RegExp(r'([\u0BC6-\u0BC8])([\u0B95-\u0BB9])');
    // Swap: Vowel+Consonant -> Consonant+Vowel
    return text.replaceAllMapped(
      visualVowels,
      (Match m) => '${m.group(2)}${m.group(1)}',
    );
  }

  // 🧠 Local AI: Extractive Summarizer Algorithm
  String _generateSummary(String text, {int numSentences = 5}) {
    if (text.isEmpty) return "No text found to summarize.";

    // 1. Clean and split into sentences
    // Split by . ! ? followed by whitespace
    List<String> sentences = text
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'));

    // Remove empty sentences
    sentences = sentences.where((s) => s.trim().length > 10).toList();

    if (sentences.length <= numSentences) {
      return text;
    }

    // 2. Calculate Word Frequency (Skip stop words)
    final stopWords = {
      'the',
      'is',
      'at',
      'of',
      'on',
      'and',
      'a',
      'an',
      'in',
      'to',
      'for',
      'with',
      'it',
      'this',
      'that',
      'by',
      'from',
      'be',
      'are',
      'was',
      'were',
      'as',
      'but',
    };

    Map<String, int> wordFreq = {};
    for (var sentence in sentences) {
      // Remove punctuation and distinct words
      // Use Unicode property escape \p{L} to match any letter in any language (including Tamil)
      var words = sentence
          .toLowerCase()
          .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '')
          .split(RegExp(r'\s+'));

      for (var word in words) {
        if (word.isNotEmpty && !stopWords.contains(word)) {
          wordFreq[word] = (wordFreq[word] ?? 0) + 1;
        }
      }
    }

    // 3. Score Sentences
    Map<int, double> sentenceScores = {};

    for (int i = 0; i < sentences.length; i++) {
      var words = sentences[i]
          .toLowerCase()
          .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '')
          .split(RegExp(r'\s+'));

      double score = 0;
      for (var word in words) {
        if (wordFreq.containsKey(word)) {
          score += wordFreq[word]!;
        }
      }
      if (words.isNotEmpty) {
        sentenceScores[i] = score / words.length;
      }
    }

    // 4. Get Top N Sentences
    var sortedIndices = sentenceScores.keys.toList()
      ..sort((a, b) => sentenceScores[b]!.compareTo(sentenceScores[a]!));

    var topIndices = sortedIndices.take(numSentences).toList()..sort();

    // 5. Reconstruct Summary
    StringBuffer summary = StringBuffer();
    for (var index in topIndices) {
      // Clean up punctuation spacing
      var s = sentences[index].trim();
      summary.write(s);

      // Add space if sentence doesn't end with newline
      if (!s.endsWith('\n')) summary.write(' ');
    }

    return summary.toString().trim();
  }
}
