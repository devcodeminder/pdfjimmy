import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:math';
import '../models/reading_stats.dart';

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
  bool _isInitializing = false; // Lock to prevent concurrent readPage calls
  double _speechRate = 0.5; // Back to normal speed (0.5 is standard)
  double _pitch = 1.0; // 0.5 to 2.0
  double _volume = 1.0; // 0.0 to 1.0
  List<PdfSentence> _sentences = [];
  int _currentSentenceIndex = 0;
  List<String> _currentSpokenWords =
      []; // Words split from normalized spoken text
  List<PdfWordBound> _currentWordBounds = [];
  Size _currentPageSize = Size.zero;

  // Advanced Features
  bool _autoPageTurn = true;
  int _currentPageNumber = 0;
  int _totalPages = 0;
  DateTime? _readingStartTime;
  int _totalWordsRead = 0;
  int _totalSentencesRead = 0;

  // Callbacks
  Function(int currentPage, int totalPages)? onPageComplete;
  Function(ReadingStats)? onStatsUpdate;

  Size get currentPageSize => _currentPageSize;
  bool get autoPageTurn => _autoPageTurn;
  ReadingStats get currentStats => ReadingStats(
    wordsRead: _totalWordsRead,
    sentencesRead: _totalSentencesRead,
    readingTime: _readingStartTime != null
        ? DateTime.now().difference(_readingStartTime!)
        : Duration.zero,
    currentPage: _currentPageNumber,
    totalPages: _totalPages,
  );

  PdfTtsService() {
    _initializeTts();
  }

  // Callback emits: Text, Start, End, FullText, Rects
  Function(String, int, int, String, List<Rect>?)? onSpeakProgress;

  /// Enable/disable auto page turn
  void setAutoPageTurn(bool enabled) {
    _autoPageTurn = enabled;
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(_volume);

      // On Android/iOS, using a dedicated instance can help with settings application
      // and prevent word-by-word stuttering on some engines
      if (Platform.isAndroid || Platform.isIOS) {
        await _tts.setSharedInstance(false);
      }

      // Android specific: Force default engine if possible to ensure compatibility
      if (Platform.isAndroid) {
        try {
          await _tts.setEngine("com.google.android.tts");
        } catch (_) {}
      }

      // Enable word-by-word progress tracking for highlighting ONLY
      // This should NOT affect the actual speech flow
      _tts.setProgressHandler((text, start, end, word) {
        _handleWordProgress(text, start, end);
      });

      // We rely on completion to trigger the next sentence
      // On Windows, we use await speak() pattern instead of completion handler
      if (!Platform.isWindows) {
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
      }

      // Error handler
      _tts.setErrorHandler((msg) {
        print('TTS Error: $msg');
        // Only reset state if we are NOT paused
        // On Android, stop() triggers an error "interrupted" which is expected during pause
        if (!_isPaused) {
          _isReading = false;
          // _isPaused = false; // Already false if we are here
        }
      });
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  /// Read the current page aloud with advanced features
  Future<void> readPage(
    String filePath,
    int pageNumber, {
    int? totalPages,
  }) async {
    print('PdfTtsService: readPage start: $pageNumber');

    // Prevent concurrent initialization
    if (_isInitializing) {
      print('PdfTtsService: Already initializing, ignoring duplicate call');
      return;
    }

    _isInitializing = true;
    try {
      // Validate inputs
      if (filePath.isEmpty) {
        print('PdfTtsService: Error - Empty file path');
        return;
      }

      if (pageNumber < 1) {
        print('PdfTtsService: Error - Invalid page number: $pageNumber');
        return;
      }

      // Stop any ongoing reading
      if (_isReading) {
        print('PdfTtsService: Stopping previous reading session');
        await stop();
        // Small delay to ensure TTS engine is ready
        await Future.delayed(Duration(milliseconds: 100));
      }

      _currentPageNumber = pageNumber;
      _totalPages = totalPages ?? 0;

      // Validate page number is within range
      if (_totalPages > 0 && pageNumber > _totalPages) {
        print(
          'PdfTtsService: Error - Page $pageNumber exceeds total pages $_totalPages',
        );
        return;
      }

      // Start reading session tracking
      if (_readingStartTime == null) {
        _readingStartTime = DateTime.now();
        print('PdfTtsService: Starting new reading session');
      }

      // Extract text and bounds together
      try {
        await _extractTextAndBounds(filePath, pageNumber);
      } catch (e) {
        print('PdfTtsService: Error extracting text: $e');
        _isReading = false;
        return;
      }

      if (_sentences.isEmpty) {
        print('PdfTtsService: No sentences found on page $pageNumber');
        // Auto-advance if enabled and not on last page
        if (_autoPageTurn && _totalPages > 0 && pageNumber < _totalPages) {
          print('PdfTtsService: Auto-advancing to next page (empty page)');
          await Future.delayed(Duration(milliseconds: 500));
          onPageComplete?.call(pageNumber + 1, _totalPages);
        } else {
          print('PdfTtsService: No more pages to read or auto-turn disabled');
        }
        return;
      }

      print(
        'PdfTtsService: Found ${_sentences.length} sentences. Starting playback.',
      );

      // --- LANGUAGE DETECTION ---
      // Sample the text to detect language
      StringBuffer sampleText = StringBuffer();
      for (var s in _sentences) {
        sampleText.write(s.text);
        if (sampleText.length > 500) break; // Check first 500 chars
      }

      String detectedLang = _detectLanguage(sampleText.toString());
      print('PdfTtsService: Detected Language: $detectedLang');

      try {
        await _tts.setLanguage(detectedLang);
      } catch (e) {
        print('PdfTtsService: Error setting language: $e');
      }
      // ---------------------------

      _isReading = true;
      _isPaused = false;
      _currentSentenceIndex = 0;

      // Tiny delay to ensure previous TTS commands cleared
      await Future.delayed(Duration(milliseconds: 50));

      // Start speaking
      try {
        await _speakNextSentence();
      } catch (e) {
        print('PdfTtsService: Error starting speech: $e');
        _isReading = false;
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Detect language based on Unicode character ranges
  String _detectLanguage(String text) {
    if (text.isEmpty) return 'en-US';

    int tamilCount = 0;
    int hindiCount = 0; // Devanagari
    int teluguCount = 0;
    int kannadaCount = 0;
    int malayalamCount = 0;
    int bengaliCount = 0;
    int gujaratiCount = 0;
    int punjabiCount = 0;

    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);

      if (code >= 0x0B80 && code <= 0x0BFF) {
        tamilCount++;
      } else if (code >= 0x0900 && code <= 0x097F) {
        hindiCount++;
      } else if (code >= 0x0C00 && code <= 0x0C7F) {
        teluguCount++;
      } else if (code >= 0x0C80 && code <= 0x0CFF) {
        kannadaCount++;
      } else if (code >= 0x0D00 && code <= 0x0D7F) {
        malayalamCount++;
      } else if (code >= 0x0980 && code <= 0x09FF) {
        bengaliCount++;
      } else if (code >= 0x0A80 && code <= 0x0AFF) {
        gujaratiCount++;
      } else if (code >= 0x0A00 && code <= 0x0A7F) {
        punjabiCount++;
      }
    }

    // Heuristics: if any Indic script matches more than 10 chars or is dominant, use it.
    // We prioritize Indic scripts because English chars (like 'PDF', numbers) are common in Indic texts.

    Map<String, int> counts = {
      'ta-IN': tamilCount,
      'hi-IN': hindiCount,
      'te-IN': teluguCount,
      'kn-IN': kannadaCount,
      'ml-IN': malayalamCount,
      'bn-IN': bengaliCount,
      'gu-IN': gujaratiCount,
      'pa-IN': punjabiCount,
    };

    // Find the max count among Indic languages
    String bestLang = 'en-US';
    int maxCount = 0;

    counts.forEach((lang, count) {
      if (count > maxCount) {
        maxCount = count;
        bestLang = lang;
      }
    });

    // Use percentage-based threshold for better accuracy
    final totalChars = text.length;
    if (totalChars > 0 && maxCount > 10) {
      final percentage = (maxCount / totalChars) * 100;
      // If > 30% of content is Indic script, use that language
      if (percentage > 30) {
        return bestLang;
      }
    }

    // Default to English if no strong signal for others
    return 'en-US';
  }

  // 🛠️ Advanced Tamil Text Repair for Broken PDFs (Copied from OfflineAiService)
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

  Future<void> _speakNextSentence() async {
    // Safety check: ensure we're still in reading mode
    if (!_isReading || _isPaused) {
      print('PdfTtsService: Not reading or paused, stopping sentence playback');
      return;
    }

    // Check if we've finished all sentences
    if (_currentSentenceIndex >= _sentences.length) {
      print(
        'PdfTtsService: Finished all sentences on page $_currentPageNumber.',
      );

      // Update statistics
      _totalSentencesRead += _sentences.length;
      _updateStats();

      // Auto-advance to next page if enabled
      if (_autoPageTurn &&
          _totalPages > 0 &&
          _currentPageNumber < _totalPages) {
        print(
          'PdfTtsService: Auto-advancing to page ${_currentPageNumber + 1}',
        );
        _isReading = false; // Mark as not reading before page change
        await Future.delayed(
          Duration(milliseconds: 800),
        ); // Brief pause between pages

        // Call page complete callback
        try {
          onPageComplete?.call(_currentPageNumber + 1, _totalPages);
        } catch (e) {
          print('PdfTtsService: Error in page complete callback: $e');
        }
      } else {
        print('PdfTtsService: Stopping - no more pages or auto-turn disabled');
        await stop();
      }
      return;
    }

    // Get current sentence
    final sentence = _sentences[_currentSentenceIndex];
    print(
      'PdfTtsService: Speaking sentence $_currentSentenceIndex/${_sentences.length}: "${sentence.text.substring(0, min(20, sentence.text.length))}..."',
    );

    // Update word count
    final wordCount = sentence.text
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .length;
    _totalWordsRead += wordCount;
    _updateStats(); // Ensure stats update immediately for UI

    // Don't pre-highlight the sentence - let the progress handler do word-by-word highlighting

    // Speak the sentence
    try {
      final textToSpeak = sentence.text.trim();

      if (textToSpeak.isEmpty) {
        print('PdfTtsService: Skipping empty sentence');
        _currentSentenceIndex++;
        await _speakNextSentence();
        return;
      }

      // Normalize text for natural TTS speech
      String normalizedText = textToSpeak
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // --- HEALING ALGORITHM: Merge separated letters (e.g. "H e l l o" -> "Hello") ---
      String previousText = "";
      while (previousText != normalizedText) {
        previousText = normalizedText;
        normalizedText = normalizedText.replaceAllMapped(
          RegExp(r'\b(?![aAiI]\b)([a-zA-Z])\s+(?![aAiI]\b)([a-zA-Z])\b'),
          (Match m) => '${m.group(1)}${m.group(2)}',
        );
      }

      // Ensure text ends with punctuation for natural pauses
      if (!normalizedText.endsWith('.') &&
          !normalizedText.endsWith('!') &&
          !normalizedText.endsWith('?')) {
        normalizedText += '.';
      }

      // Store the normalized spoken words so the progress handler can
      // map character offsets to sequential word indices for highlighting.
      _currentSpokenWords = normalizedText
          .split(RegExp(r'\s+'))
          .where((w) => w.trim().isNotEmpty)
          .toList();

      print(
        'PdfTtsService: Speaking SENTENCE: "${normalizedText.substring(0, min(40, normalizedText.length))}..."',
      );
      print(
        'PdfTtsService: Sentence has ${sentence.wordBounds.length} word bounds, ${_currentSpokenWords.length} spoken words',
      );

      print('PdfTtsService: ▶️ STARTING to speak sentence...');
      await _tts.speak(normalizedText);
      print('PdfTtsService: ✅ FINISHED speaking sentence');

      // Platform-specific handling
      if (Platform.isWindows) {
        // On Windows, await completes when speaking finishes
        print(
          'PdfTtsService: Windows TTS completed, advancing to next sentence',
        );
        _currentSentenceIndex++;
        _updateStats(); // Update stats after each sentence

        // Check bounds and state before continuing
        if (_isReading &&
            !_isPaused &&
            _currentSentenceIndex < _sentences.length) {
          await _speakNextSentence();
        } else if (_currentSentenceIndex >= _sentences.length) {
          // Finished all sentences
          print('PdfTtsService: Windows - Finished all sentences');
          await stop();
        }
      }
      // On other platforms, completion handler will trigger next sentence
    } catch (e) {
      print('PdfTtsService: Error speaking sentence: $e');
      // Try to recover by moving to next sentence
      _currentSentenceIndex++;
      if (_isReading &&
          !_isPaused &&
          _currentSentenceIndex < _sentences.length) {
        print(
          'PdfTtsService: Attempting to recover by skipping to next sentence',
        );
        await Future.delayed(Duration(milliseconds: 200));
        await _speakNextSentence();
      } else {
        print('PdfTtsService: Stopping due to error');
        _isReading = false;
      }
    }
  }

  /// Handle word-by-word progress from TTS engine
  ///
  /// Uses a simple sequential word index approach:
  /// - The TTS engine fires progress events as it speaks each word
  /// - We use the character offset (start) to determine which word number we're on
  /// - We map that word number directly to the wordBounds array
  /// - No text matching needed — just sequential index lookup
  void _handleWordProgress(String text, int start, int end) {
    if (!_isReading || _isPaused) return;
    if (_currentSentenceIndex >= _sentences.length) return;

    final currentSentence = _sentences[_currentSentenceIndex];
    if (currentSentence.wordBounds.isEmpty) return;

    // Extract the spoken word from the progress callback
    final safeEnd = end.clamp(0, text.length);
    final safeStart = start.clamp(0, safeEnd);
    final spokenWord = text.substring(safeStart, safeEnd).trim();
    if (spokenWord.isEmpty) return;

    // --- SEQUENTIAL INDEX APPROACH ---
    // Calculate which word index we're at based on character offset into the spoken text.
    // This is reliable because the TTS engine fires progress in order.
    int wordIndex = 0;
    if (_currentSpokenWords.isNotEmpty) {
      int charCount = 0;
      for (int i = 0; i < _currentSpokenWords.length; i++) {
        int wordEnd = charCount + _currentSpokenWords[i].length;
        if (start >= charCount && start < wordEnd + 2) {
          wordIndex = i;
          break;
        }
        charCount += _currentSpokenWords[i].length + 1; // +1 for space
      }
    }

    // Map the spoken word index to the PDF word bounds array.
    // The spoken words may differ from PDF words (due to healing/normalization),
    // so we clamp the index to the available bounds.
    final boundIndex = wordIndex.clamp(
      0,
      currentSentence.wordBounds.length - 1,
    );
    final wordBound = currentSentence.wordBounds[boundIndex];
    final wordRects = [wordBound.bounds];

    print(
      'TTS Progress: word="$spokenWord" idx=$wordIndex → bound[${boundIndex}]="${wordBound.text}" rect=${wordBound.bounds}',
    );

    // Notify UI
    try {
      if (onSpeakProgress != null) {
        onSpeakProgress!(
          spokenWord,
          start,
          end,
          currentSentence.text,
          wordRects,
        );
      }
    } catch (e) {
      print('TTS Progress: Error in callback: $e');
    }
  }

  void _updateStats() {
    onStatsUpdate?.call(currentStats);
  }

  /// Extract text and build word/bounds map AND Sentences using Global Sort & Merge
  Future<void> _extractTextAndBounds(String filePath, int pageNumber) async {
    print('PdfTtsService: extracting text for page $pageNumber');
    _currentWordBounds.clear();
    _sentences.clear();

    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      _currentPageSize = document.pages[pageNumber - 1].size;

      PdfTextExtractor extractor = PdfTextExtractor(document);

      // Extract text lines with bounds
      List<TextLine> lines = extractor.extractTextLines(
        startPageIndex: pageNumber - 1,
        endPageIndex: pageNumber - 1,
      );

      // 1. FLAT COLLECTION: Ignore line structure, get all atoms
      List<PdfWordBound> atoms = [];
      for (var line in lines) {
        for (var word in line.wordCollection) {
          if (word.text.trim().isEmpty) continue;
          atoms.add(
            PdfWordBound(
              text: word.text,
              bounds: word.bounds,
              startIndex: 0,
              endIndex: 0,
            ),
          );
        }
      }

      // 2. ROBUST SORTING: Sort by Y (bands) then X for correct reading order.
      // Syncfusion PdfTextExtractor uses screen-space coordinates: Y=0 at top,
      // so 'top' < 'bottom' and ascending sort by 'top' = top-to-bottom order.
      atoms.sort((a, b) {
        double height = max(a.bounds.height, b.bounds.height);
        double topDiff =
            a.bounds.top -
            b.bounds.top; // ASCENDING: smaller top (higher on page) first

        if (topDiff.abs() < height * 0.5) {
          // Same line — sort left to right by X
          return (a.bounds.left - b.bounds.left).sign.toInt();
        }
        // Different lines — sort top-to-bottom
        return topDiff.sign.toInt();
      });

      // 3. AGGRESSIVE MERGING
      List<PdfWordBound> mergedWords = [];
      if (atoms.isNotEmpty) {
        PdfWordBound current = atoms[0];

        for (int i = 1; i < atoms.length; i++) {
          PdfWordBound next = atoms[i];

          // Line Check: Do they overlap vertically?
          // Syncfusion uses screen-space coords (top < bottom), so standard
          // overlap check applies: two rects overlap if one's top < other's bottom.
          bool verticalOverlap =
              current.bounds.top < next.bounds.bottom &&
              next.bounds.top < current.bounds.bottom;

          // Gap Check:
          double fontHeight = current.bounds.height;
          double gap = next.bounds.left - current.bounds.right;

          // Thresholds:
          // Normal word gap is ~0.3 * height.
          // Fragmentation gap is ~0.05 * height.
          // We set threshold high (0.35) to catch almost everything except clear spaces.
          // If both are single chars ("T" "h"), we go even higher (0.8) to force merge "I" "a" -> "Ia" if needed, because "I-a" disjoint reading is worse.

          bool bothSingle = current.text.length == 1 && next.text.length == 1;
          double threshold = bothSingle ? fontHeight * 0.8 : fontHeight * 0.35;

          // Special case: If 'next' text is valid punctuation, MERGE it to previous word
          bool isPunctuation = RegExp(r'^[.,!?;:]$').hasMatch(next.text);

          if (verticalOverlap && (gap < threshold || isPunctuation)) {
            // MERGE
            current = PdfWordBound(
              text: current.text + next.text,
              bounds: current.bounds.expandToInclude(next.bounds),
              startIndex: 0,
              endIndex: 0,
            );
          } else {
            // PUSH
            mergedWords.add(current);
            current = next;
          }
        }
        mergedWords.add(current); // Add last
      }

      // 4. Build Sentences
      StringBuffer sentenceBuffer = StringBuffer();
      List<Rect> sentenceRects = [];
      List<PdfWordBound> sentenceWordBounds = [];
      int currentIndex = 0;

      for (var word in mergedWords) {
        final wordBound = PdfWordBound(
          text: word.text,
          bounds: word.bounds,
          startIndex: currentIndex,
          endIndex: currentIndex + word.text.length,
        );

        _currentWordBounds.add(wordBound);
        sentenceWordBounds.add(wordBound);

        sentenceBuffer.write(word.text);
        currentIndex += word.text.length;
        sentenceRects.add(word.bounds);

        // Break on sentence-ending punctuation
        bool isDelimiter =
            word.text.endsWith('.') ||
            word.text.endsWith('!') ||
            word.text.endsWith('?') ||
            word.text.endsWith(':') ||
            word.text.endsWith(';');

        // Add space
        sentenceBuffer.write(' ');
        currentIndex += 1;

        // Also break on word count limit.
        // Many PDFs (forms, tables, tax receipts, certificates) have no
        // sentence punctuation. Without this, the entire page becomes one
        // giant sentence and the highlight box covers everything.
        // Max 10 words per TTS chunk keeps the highlight tight and readable.
        bool isWordLimitReached = sentenceWordBounds.length >= 10;

        if (isDelimiter || isWordLimitReached) {
          String rawText = sentenceBuffer.toString().trim();
          if (rawText.isNotEmpty) {
            String fixedText = _fixTamilVisualOrder(
              _applyHeuristicFixes(rawText),
            );
            _addSentence(
              fixedText,
              List.from(sentenceRects),
              List.from(sentenceWordBounds),
            );
          }
          sentenceBuffer.clear();
          sentenceRects.clear();
          sentenceWordBounds.clear();
          currentIndex = 0;
        }
      }

      if (sentenceBuffer.isNotEmpty) {
        String rawText = sentenceBuffer.toString().trim();
        if (rawText.isNotEmpty) {
          String fixedText = _fixTamilVisualOrder(
            _applyHeuristicFixes(rawText),
          );
          _addSentence(
            fixedText,
            List.from(sentenceRects),
            List.from(sentenceWordBounds),
          );
        }
      }

      document.dispose();
      print(
        'PdfTtsService: Extraction complete. Sentences: ${_sentences.length}',
      );
    } catch (e) {
      print('PdfTtsService: Error extracting text: $e');
    }
  }

  void _addSentence(
    String text,
    List<Rect> rawRects,
    List<PdfWordBound> wordBounds,
  ) {
    if (text.isEmpty) return;
    // Simple merge: just take the union of all rects that are close?
    // Actually, passing raw rects is better for highlighting individually
    // But for "sentence highlight" we often want a bounding box per line.

    // Group rects by line (Y coordinate)
    Map<int, List<Rect>> lines = {};
    for (var r in rawRects) {
      int y = (r.top / 10).floor(); // Cluster by ~10 pixels
      lines.putIfAbsent(y, () => []).add(r);
    }

    List<Rect> mergedRects = [];
    lines.forEach((key, lineRects) {
      if (lineRects.isEmpty) return;
      Rect merged = lineRects.first;
      for (int i = 1; i < lineRects.length; i++) {
        merged = merged.expandToInclude(lineRects[i]);
      }
      mergedRects.add(merged);
    });

    _sentences.add(
      PdfSentence(text: text, rects: mergedRects, wordBounds: wordBounds),
    );
  }

  /// Pause the current reading
  Future<void> pause() async {
    print('PdfTtsService: Pause requested');
    print(
      'PdfTtsService: Current state BEFORE pause - _isPaused: $_isPaused, _isReading: $_isReading',
    );
    print(
      'PdfTtsService: Current sentence index: $_currentSentenceIndex / ${_sentences.length}',
    );

    if (_isReading && !_isPaused) {
      try {
        _isPaused =
            true; // Set flag FIRST to prevent completion handler from firing
        print('PdfTtsService: ✅ Set _isPaused = true');
        await _tts.stop(); // Stop speaking execution
        print('PdfTtsService: ✅ TTS stopped successfully');
        print(
          'PdfTtsService: ✅ Paused successfully - _isPaused: $_isPaused, _isReading: $_isReading',
        );
        // Note: We keep _isReading = true so we can resume
      } catch (e) {
        print('PdfTtsService: ❌ Error pausing: $e');
        _isPaused = false; // Revert if failed
      }
    } else {
      print(
        'PdfTtsService: ❌ Cannot pause - _isReading: $_isReading, _isPaused: $_isPaused',
      );
      if (!_isReading) {
        print('PdfTtsService: ❌ Not in reading mode!');
      }
      if (_isPaused) {
        print('PdfTtsService: ❌ Already paused!');
      }
    }
  }

  /// Resume reading after pause
  Future<void> resume() async {
    print('PdfTtsService: Resume requested');
    print(
      'PdfTtsService: Current state - _isPaused: $_isPaused, _isReading: $_isReading',
    );
    print(
      'PdfTtsService: Current sentence index: $_currentSentenceIndex / ${_sentences.length}',
    );
    print('PdfTtsService: _isInitializing: $_isInitializing');

    if (_isPaused && _isReading) {
      try {
        _isPaused = false;
        print('PdfTtsService: ✅ Resuming from sentence $_currentSentenceIndex');
        print('PdfTtsService: Calling _speakNextSentence()...');
        await _speakNextSentence();
        print('PdfTtsService: ✅ Resume completed successfully');
      } catch (e) {
        print('PdfTtsService: ❌ Error resuming: $e');
        _isPaused = true; // Revert to paused state
      }
    } else {
      print(
        'PdfTtsService: ❌ Cannot resume - _isPaused: $_isPaused, _isReading: $_isReading',
      );
      if (!_isPaused) {
        print('PdfTtsService: ❌ Not in paused state!');
      }
      if (!_isReading) {
        print('PdfTtsService: ❌ Not in reading mode!');
      }
    }
  }

  /// Stop reading completely
  Future<void> stop() async {
    print('PdfTtsService: Stop requested (Stack Trace available if needed)');
    try {
      _isReading = false;
      _isPaused = false;
      _currentWordBounds.clear();
      _sentences.clear();
      _currentSentenceIndex = 0;
      await _tts.stop();
      print('PdfTtsService: Stopped successfully');
    } catch (e) {
      print('PdfTtsService: Error stopping: $e');
      // Force state reset even if TTS stop fails
      _isReading = false;
      _isPaused = false;
    }
  }

  /// Reset reading session (clears stats)
  void resetSession() {
    _readingStartTime = null;
    _totalWordsRead = 0;
    _totalSentencesRead = 0;
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

  /// Set specific voice (for reading)
  Future<void> setVoice(Map<String, String> voice) async {
    try {
      _readVoiceMap = voice;
      await _tts.setVoice(voice);
    } catch (e) {
      print('Error setting voice: $e');
    }
  }

  /// Switch voice while reading (for real-time updates)
  Future<void> switchVoiceWhileReading(Map<String, String> voice) async {
    try {
      _readVoiceMap = voice;
      await _tts.setVoice(voice);

      // If we are currently reading (and not paused), we need to restart the current sentence
      // to hear the change immediately.
      if (_isReading && !_isPaused) {
        print('PdfTtsService: Switching voice in real-time...');

        // Disable completion handler (prevent auto-advance)
        _isReading = false;

        await _tts.stop();

        // Wait for engine/handler to settle
        await Future.delayed(const Duration(milliseconds: 150));

        // Re-enable and resume
        _isReading = true;
        await _speakNextSentence();
      }
    } catch (e) {
      print('Error switching voice: $e');
    }
  }

  /// Store the translation voice (applied when reading translated text)
  Map<String, String>? _readVoiceMap;
  Map<String, String>? _translationVoiceMap;

  Map<String, String>? get readVoiceMap => _readVoiceMap;
  Map<String, String>? get translationVoiceMap => _translationVoiceMap;

  /// Set voice to use for translation playback
  Future<void> setTranslationVoice(Map<String, String> voice) async {
    try {
      _translationVoiceMap = voice;
      print('PdfTtsService: Translation voice set to ${voice['name']}');
    } catch (e) {
      print('Error setting translation voice: $e');
    }
  }

  /// Apply the read voice (call before reading original text)
  Future<void> applyReadVoice() async {
    if (_readVoiceMap != null) {
      await setVoice(_readVoiceMap!);
    }
  }

  /// Apply the translation voice (call before reading translated text)
  Future<void> applyTranslationVoice() async {
    if (_translationVoiceMap != null) {
      try {
        await _tts.setVoice(_translationVoiceMap!);
      } catch (e) {
        print('Error applying translation voice: $e');
      }
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
  final List<Rect> rects; // Merged sentence-level rectangles
  final List<PdfWordBound> wordBounds; // Individual word bounds

  PdfSentence({
    required this.text,
    required this.rects,
    this.wordBounds = const [],
  });
}
