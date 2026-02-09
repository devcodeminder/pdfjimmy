import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:math';

/// DTO to hold word bounds and indices
class PdfWordBound {
  final String text;
  final Rect bounds;
  final int startIndex;
  final int endIndex;

  PdfWordBound({
    required this.text,
    required this.bounds,
    required this.startIndex,
    required this.endIndex,
  });
}

/// Service for Text-to-Speech functionality for PDF reading
class PdfTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isReading = false;
  bool _isPaused = false;
  double _speechRate = 0.5; // 0.0 to 1.0 (slow to fast)
  double _pitch = 1.0; // 0.5 to 2.0
  double _volume = 1.0; // 0.0 to 1.0
  String _currentText = '';
  List<PdfSentence> _sentences = [];
  int _currentSentenceIndex = 0;
  List<PdfWordBound> _currentWordBounds = [];
  Size _currentPageSize = Size.zero;

  Size get currentPageSize => _currentPageSize;

  PdfTtsService() {
    _initializeTts();
  }

  // Callback emits: Text, Start, End, FullText, Rects
  Function(String, int, int, String, List<Rect>?)? onSpeakProgress;

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(_volume);

      // We rely on completion to trigger the next sentence
      _tts.setCompletionHandler(() {
        if (_isReading && !_isPaused) {
          _currentSentenceIndex++;
          if (_currentSentenceIndex < _sentences.length) {
            _speakNextSentence();
          } else {
            stop();
          }
        }
      });

      // Error handler
      _tts.setErrorHandler((msg) {
        print('TTS Error: $msg');
        _isReading = false;
        _isPaused = false;
      });
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  /// Read the current page aloud
  Future<void> readPage(String filePath, int pageNumber) async {
    print('PdfTtsService: readPage start: $pageNumber');
    if (_isReading) {
      await stop();
    }

    // Extract text and bounds together
    await _extractTextAndBounds(filePath, pageNumber);

    if (_sentences.isEmpty) {
      print('PdfTtsService: No sentences found on page $pageNumber');
      return;
    }

    print(
      'PdfTtsService: Found ${_sentences.length} sentences. Starting playback.',
    );
    _isReading = true;
    _isPaused = false;
    _currentSentenceIndex = 0;

    // Tiny delay to ensure previous TTS commands cleared
    await Future.delayed(Duration(milliseconds: 50));
    _speakNextSentence();
  }

  Future<void> _speakNextSentence() async {
    if (_currentSentenceIndex >= _sentences.length) {
      print('PdfTtsService: Finished all sentences.');
      stop();
      return;
    }

    final sentence = _sentences[_currentSentenceIndex];
    print(
      'PdfTtsService: Speaking sentence $_currentSentenceIndex: "${sentence.text.substring(0, min(20, sentence.text.length))}..."',
    );

    // Notify UI (Highlight whole sentence)
    if (onSpeakProgress != null) {
      onSpeakProgress!(
        sentence.text,
        0,
        sentence.text.length,
        _currentText,
        sentence.rects,
      );
    }

    try {
      if (sentence.text.trim().isNotEmpty) {
        await _tts.speak(sentence.text);
      } else {
        // Skip empty/whitespace sentences
        print('PdfTtsService: Skipping empty sentence');
        _currentSentenceIndex++;
        _speakNextSentence();
      }
    } catch (e) {
      print('PdfTtsService: Error speaking sentence: $e');
      _isReading = false;
    }
  }

  /// Extract text and build word/bounds map AND Sentences
  Future<void> _extractTextAndBounds(String filePath, int pageNumber) async {
    print('PdfTtsService: extracting text for page $pageNumber');
    _currentText = '';
    _currentWordBounds.clear();
    _sentences.clear();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('PdfTtsService: File not found: $filePath');
        return;
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      if (pageNumber < 1 || pageNumber > document.pages.count) {
        document.dispose();
        return;
      }

      // Use PdfTextExtractor to get lines and words
      _currentPageSize = document.pages[pageNumber - 1].size;
      final extractor = PdfTextExtractor(document);
      final lines = extractor.extractTextLines(
        startPageIndex: pageNumber - 1,
        endPageIndex: pageNumber - 1,
      );

      final buffer = StringBuffer();
      int currentIndex = 0;

      // Temporary buffers for sentence building
      StringBuffer sentenceBuffer = StringBuffer();
      List<Rect> sentenceRects = [];
      // We don't need exact word indices for sentence mode, just valid rects

      for (var line in lines) {
        for (var word in line.wordCollection) {
          final text = word.text;
          final bounds = word.bounds;

          _currentWordBounds.add(
            PdfWordBound(
              text: text,
              bounds: bounds,
              startIndex: currentIndex,
              endIndex: currentIndex + text.length,
            ),
          );

          buffer.write(text);
          sentenceBuffer.write(text);
          currentIndex += text.length;

          // Merge bounds for the sentence
          // We can just add valid bounds to the list, we'll merge them visually in UI or here
          // For now, let's just collect ALL word bounds.
          // Optimization: Merge on line basis here?
          // _getRectsForRange logic can be reused or simplified.
          sentenceRects.add(bounds);

          bool isDelimiter =
              text.endsWith('.') || text.endsWith('!') || text.endsWith('?');

          buffer.write(' ');
          sentenceBuffer.write(' ');
          currentIndex += 1;

          if (isDelimiter) {
            // Finish sentence
            _addSentence(
              sentenceBuffer.toString().trim(),
              List.from(sentenceRects),
            );
            sentenceBuffer.clear();
            sentenceRects.clear();
          }
        }
        buffer.write('\n');
        // Treat newline as potential delimiter?
        // Usually, PDF text flows. We rely on punctuation.
        // But if buffer gets too long without punctuation?
        currentIndex += 1;
      }

      // Add remaining
      if (sentenceBuffer.isNotEmpty) {
        _addSentence(
          sentenceBuffer.toString().trim(),
          List.from(sentenceRects),
        );
      }

      _currentText = buffer.toString();
      document.dispose();
      print(
        'PdfTtsService: Extraction complete. Text length: ${_currentText.length}',
      );
    } catch (e) {
      print('PdfTtsService: Error extracting text/bounds: $e');
    }
  }

  void _addSentence(String text, List<Rect> rawRects) {
    if (text.isEmpty) return;

    // Optimize rects (merge overlapping/adjacent on same line)
    // Similar to _getRectsForRange logic
    List<Rect> mergedRects = [];
    for (var r in rawRects) {
      bool added = false;
      for (int i = 0; i < mergedRects.length; i++) {
        final line = mergedRects[i];
        if ((line.top - r.top).abs() < 5 &&
            (line.bottom - r.bottom).abs() < 5) {
          mergedRects[i] = line.expandToInclude(r);
          added = true;
          break;
        }
      }
      if (!added) {
        mergedRects.add(r);
      }
    }

    _sentences.add(PdfSentence(text: text, rects: mergedRects));
  }

  /// Pause the current reading
  Future<void> pause() async {
    if (_isReading && !_isPaused) {
      await _tts.stop(); // Stop speaking execution
      _isPaused = true;
      // UI might keep highlight or clear it. Usually clear or keep "paused" state.
      // onSpeakProgress!('', -1, -1, '', null);
    }
  }

  /// Resume reading after pause
  Future<void> resume() async {
    if (_isPaused) {
      _isPaused = false;
      _speakNextSentence();
    }
  }

  /// Stop reading completely
  Future<void> stop() async {
    _isReading = false;
    _isPaused = false;
    _currentText = '';
    _currentWordBounds.clear();
    _sentences.clear();
    await _tts.stop();
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speechRate);
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  /// Get available languages
  Future<List<String>> getLanguages() async {
    try {
      final languages = await _tts.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (e) {
      print('Error setting language: $e');
    }
  }

  /// Get available voices
  Future<List<Map<Object?, Object?>>> getVoices() async {
    try {
      final voices = await _tts.getVoices;
      return List<Map<Object?, Object?>>.from(voices ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Set specific voice
  Future<void> setVoice(Map<String, String> voice) async {
    try {
      await _tts.setVoice(voice);
    } catch (e) {
      print('Error setting voice: $e');
    }
  }

  // Getters
  bool get isReading => _isReading;
  bool get isPaused => _isPaused;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;

  /// Dispose and clean up resources
  void dispose() {
    _tts.stop();
  }
}

class PdfSentence {
  final String text;
  final List<Rect> rects;
  PdfSentence({required this.text, required this.rects});
}
