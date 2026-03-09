import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdfjimmy/services/pdf_tts_service.dart';

class TtsPlayerWidget extends StatefulWidget {
  final String filePath;
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;
  final VoidCallback onClose;
  final Function(String, int, int, String, List<Rect>?, Size)? onWordSpoken;
  final Color currentHighlightColor;
  final Function(Color)? onHighlightColorChanged;
  final PdfTtsService? ttsService;

  const TtsPlayerWidget({
    Key? key,
    required this.filePath,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.onClose,
    this.onWordSpoken,
    this.currentHighlightColor = Colors.greenAccent,
    this.onHighlightColorChanged,
    this.ttsService,
  }) : super(key: key);

  @override
  State<TtsPlayerWidget> createState() => TtsPlayerWidgetState();
}

class TtsPlayerWidgetState extends State<TtsPlayerWidget> {
  late final PdfTtsService _ttsService;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _speed = 0.5;
  double _pitch = 1.0;
  List<Map<Object?, Object?>> _voices = [];
  Map<Object?, Object?>? _readVoice; // voice for reading PDF
  Map<Object?, Object?>? _translationVoice; // voice for translation language
  bool _showSettings = false;
  bool _translationModeEnabled =
      false; // whether to translate sentences while reading
  final TextEditingController _langSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? PdfTtsService();

    // *** CRITICAL: Set up callbacks SYNCHRONOUSLY before any async work.
    // If callbacks are set inside an async method (after an await), there is
    // a window where TTS can start firing progress events while onSpeakProgress
    // is still null — causing highlighting to silently fail.
    _ttsService.onSpeakProgress =
        (String word, int start, int end, String allText, List<Rect>? rects) {
          if (mounted && widget.onWordSpoken != null) {
            widget.onWordSpoken!(
              word,
              start,
              end,
              allText,
              rects,
              _ttsService.currentPageSize,
            );
          }
        };

    _ttsService.onPageComplete = (int nextPage, int total) async {
      if (mounted) {
        // nextPage is 1-indexed. widget.onPageChanged expects 0-indexed.
        widget.onPageChanged(nextPage - 1);

        if (_ttsService.autoPageTurn) {
          setState(() {
            _isLoading = true;
          });

          // Small delay to allow the PDF viewer to visually move to the next page
          await Future.delayed(const Duration(milliseconds: 500));

          try {
            await _ttsService.readPage(
              widget.filePath,
              nextPage, // readPage expects 1-indexed
              totalPages: total,
            );
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isPlaying = true;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isPlaying = false;
              });
            }
          }
        } else {
          setState(() {
            _isPlaying = false;
          });
        }
      }
    };

    // Load voices asynchronously (only for voice selection UI)
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await _ttsService.getVoices();
    if (mounted) {
      setState(() {
        _voices = voices;
      });
    }
  }

  Future<void> _togglePlay() async {
    print(
      'TtsPlayerWidget: Toggle play - current state: playing=$_isPlaying, paused=${_ttsService.isPaused}',
    );

    try {
      if (_isPlaying) {
        // Pause playback
        print('TtsPlayerWidget: Pausing playback');
        await _ttsService.pause();
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      } else {
        if (_ttsService.isPaused) {
          // Resume from pause
          print('TtsPlayerWidget: Resuming playback');
          await _ttsService.resume();
          if (mounted) {
            setState(() => _isPlaying = true);
          }
        } else {
          // Start new playback
          print(
            'TtsPlayerWidget: Starting new playback for page ${widget.currentPage + 1}',
          );

          if (mounted) {
            setState(() => _isLoading = true);
          }

          try {
            await _ttsService.readPage(
              widget.filePath,
              widget.currentPage + 1,
              totalPages: widget.totalPages,
            );

            if (mounted) {
              setState(() {
                _isLoading = false;
                _isPlaying = true;
              });
            }
          } catch (e) {
            print('TtsPlayerWidget: Error starting playback: $e');
            if (mounted) {
              setState(() => _isLoading = false);

              // Show error to user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to start reading: ${e.toString()}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('TtsPlayerWidget: Error in toggle play: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _changeSpeed(double value) {
    setState(() => _speed = value);
    _ttsService.setSpeechRate(value);
  }

  void _changePitch(double value) {
    setState(() => _pitch = value);
    _ttsService.setPitch(value);
  }

  void _changeVoice(
    Map<Object?, Object?>? voice, {
    bool isTranslation = false,
  }) {
    if (voice == null) return;

    setState(() {
      if (isTranslation) {
        _translationVoice = voice;
      } else {
        _readVoice = voice;
      }
    });

    try {
      final Map<String, String> voiceMap = {};
      voice.forEach((key, value) {
        if (key != null && value != null) {
          voiceMap[key.toString()] = value.toString();
        }
      });

      if (!isTranslation) {
        // Apply read voice — if currently reading, switch in real-time
        _ttsService.switchVoiceWhileReading(voiceMap);
      } else {
        _ttsService.setTranslationVoice(voiceMap);
        // Also update the target language in the service
        final locale = voice['locale']?.toString() ?? '';
        final langCode = locale.split('-').first.toLowerCase();
        _ttsService.setTranslationTargetLanguage(langCode);
      }
    } catch (e) {
      print('Error converting voice map: $e');
    }
  }

  /// Called by the parent screen when the user taps on the PDF while AI Reader
  /// is active. [tapY] is the Y-position in PDF page coordinates.
  ///
  /// [screenY], [scrollOffsetY], [viewerWidth], [zoom], [pageIndex] are the raw
  /// rendering params used to recompute pdfY accurately on first-tap (when pageSize
  /// isn't yet known from the viewer).
  Future<void> seekToTapPosition(
    double tapY, {
    double? screenY,
    double? scrollOffsetY,
    double? viewerWidth,
    double? zoom,
    int? pageIndex,
  }) async {
    print('TtsPlayerWidget: seekToTapPosition tapY=$tapY');

    // Show loading indicator while we load sentences (first-tap scenario)
    final bool needsLoad = !_ttsService.hasSentencesLoaded;
    if (needsLoad && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await _ttsService.seekToTapPosition(
        tapY,
        filePath: widget.filePath,
        pageNumber: widget.currentPage + 1, // convert 0-indexed → 1-indexed
        totalPages: widget.totalPages,
        screenY: screenY,
        scrollOffsetY: scrollOffsetY,
        viewerWidth: viewerWidth,
        zoom: zoom,
        pageIndex: pageIndex,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('TtsPlayerWidget: seekToTapPosition error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    print('TtsPlayerWidget: Dispose called');
    _ttsService.stop();
    _langSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1a1f2e), const Color(0xFF0f1419)]
              : [Colors.white, Colors.grey.shade50],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, -10),
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Premium Header with Gradient
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.1),
                        Theme.of(context).primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_stories_rounded,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ).animate().scale(
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'AI Reader',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Page ${widget.currentPage + 1} of ${widget.totalPages}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white38 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildTranslateToggleButton(),
                          const SizedBox(width: 4),
                          _buildPremiumIconButton(
                            icon: _showSettings
                                ? Icons.close
                                : Icons.tune_rounded,
                            onPressed: () =>
                                setState(() => _showSettings = !_showSettings),
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          _buildPremiumIconButton(
                            icon: Icons.close,
                            onPressed: widget.onClose,
                            color: Colors.red.shade400,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_showSettings) ...[
                  const SizedBox(height: 12),
                  _buildSettings()
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: -0.1, end: 0),
                ],

                const SizedBox(height: 12),

                // Premium Controls with 3D Effect
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.skip_previous_rounded,
                      onPressed: () =>
                          widget.onPageChanged(widget.currentPage - 1),
                      size: 36,
                    ),

                    // Main Play/Pause Button - Premium 3D Style
                    GestureDetector(
                          onTap: _togglePlay,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.7),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                  spreadRadius: 2,
                                ),
                                const BoxShadow(
                                  color: Colors.white38,
                                  blurRadius: 15,
                                  offset: Offset(-5, -5),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(5, 5),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: _isLoading
                                ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: CircularProgressIndicator(
                                          color: Colors.white.withOpacity(0.9),
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                      .animate(
                                        onPlay: (controller) =>
                                            controller.repeat(),
                                      )
                                      .rotate(duration: 1.seconds)
                                : Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.2),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      _isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 30,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        )
                        .animate(target: _isPlaying ? 1 : 0)
                        .shimmer(duration: 2.seconds, color: Colors.white12),

                    _buildControlButton(
                      icon: Icons.skip_next_rounded,
                      onPressed: () =>
                          widget.onPageChanged(widget.currentPage + 1),
                      size: 36,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        iconSize: 22,
      ),
    );
  }

  /// Translation toggle button shown in the header.
  Widget _buildTranslateToggleButton() {
    final isOn = _translationModeEnabled;
    final color = isOn ? Colors.orange.shade400 : Colors.grey.shade400;
    return GestureDetector(
      onTap: () {
        setState(() => _translationModeEnabled = !_translationModeEnabled);
        _ttsService.setTranslationMode(_translationModeEnabled);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
          ),
          border: Border.all(
            color: color.withOpacity(isOn ? 0.7 : 0.3),
            width: 1.5,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Icon(Icons.translate_rounded, color: color, size: 18),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)]
                : [const Color(0xFFF0F0F0), const Color(0xFFDCDCDC)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.8),
              blurRadius: 10,
              offset: const Offset(-4, -4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.55,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
        ),
      ),
    ).animate().scale(
      begin: const Offset(1, 1),
      end: const Offset(0.92, 0.92),
      duration: 150.ms,
      curve: Curves.easeInOut,
    );
  }

  // ── Voice character data ─────────────────────────────────────────────────
  // Each language gets a unique cartoon character: name, emoji, bg color.
  static const Map<String, Map<String, dynamic>> _langCharacters = {
    'ta': {'name': 'Murugan', 'emoji': '🧑‍🦱', 'color': 0xFFFF6B35}, // Tamil
    'hi': {'name': 'Arjun', 'emoji': '👳', 'color': 0xFFFF9933}, // Hindi
    'te': {'name': 'Ravi', 'emoji': '🧔', 'color': 0xFF6C63FF}, // Telugu
    'ml': {
      'name': 'Suresh',
      'emoji': '🧑‍🦳',
      'color': 0xFF00B4D8,
    }, // Malayalam
    'kn': {'name': 'Kiran', 'emoji': '👨‍🎓', 'color': 0xFF2DC653}, // Kannada
    'bn': {'name': 'Priya', 'emoji': '🧕', 'color': 0xFFE040FB}, // Bengali
    'mr': {'name': 'Ananya', 'emoji': '👩‍🦱', 'color': 0xFFFF4081}, // Marathi
    'gu': {'name': 'Dhruv', 'emoji': '🧑‍🍳', 'color': 0xFFFFAB40}, // Gujarati
    'pa': {'name': 'Gurpreet', 'emoji': '🥷', 'color': 0xFF40C4FF}, // Punjabi
    'ur': {'name': 'Zara', 'emoji': '🧙', 'color': 0xFF69F0AE}, // Urdu
    'ar': {'name': 'Khalid', 'emoji': '🧞', 'color': 0xFFFFD740}, // Arabic
    'zh': {'name': 'Mei', 'emoji': '🐉', 'color': 0xFFFF5252}, // Chinese
    'ja': {'name': 'Hana', 'emoji': '🌸', 'color': 0xFFFF80AB}, // Japanese
    'ko': {'name': 'Joon', 'emoji': '🤖', 'color': 0xFF64FFDA}, // Korean
    'fr': {'name': 'Pierre', 'emoji': '🥐', 'color': 0xFF448AFF}, // French
    'de': {'name': 'Klaus', 'emoji': '🦁', 'color': 0xFFFFD740}, // German
    'es': {'name': 'Sofia', 'emoji': '💃', 'color': 0xFFFF6E40}, // Spanish
    'pt': {'name': 'Lucas', 'emoji': '⚽', 'color': 0xFF69F0AE}, // Portuguese
    'it': {'name': 'Marco', 'emoji': '🍕', 'color': 0xFFFF5252}, // Italian
    'ru': {'name': 'Natasha', 'emoji': '🐻', 'color': 0xFF40C4FF}, // Russian
    'en': {
      'name': 'Alex',
      'emoji': '🧑‍💻',
      'color': 0xFF7C4DFF,
    }, // English (default)
    // English female names get a different character
    'en_f': {'name': 'Emma', 'emoji': '👩‍💼', 'color': 0xFFFF4081},
  };

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'tr': 'Turkish',
    'nl': 'Dutch',
    'pl': 'Polish',
    'sv': 'Swedish',
    'da': 'Danish',
    'fi': 'Finnish',
    'no': 'Norwegian',
    'el': 'Greek',
    'he': 'Hebrew',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'pa': 'Punjabi',
    'ur': 'Urdu',
    'as': 'Assamese',
    'or': 'Odia',
    'sa': 'Sanskrit',
    'si': 'Sinhala',
    'my': 'Burmese',
    'km': 'Khmer',
    'lo': 'Lao',
  };

  static const Set<String> _englishFemaleNames = {
    'zira',
    'hazel',
    'susan',
    'eva',
    'samantha',
    'victoria',
    'karen',
    'moira',
    'tessa',
    'female',
    'woman',
    'girl',
    'siri',
    'cortana',
    'lisa',
    'emma',
    'emily',
  };

  static const Set<String> _englishMaleNames = {
    'david',
    'mark',
    'george',
    'james',
    'guy',
    'richard',
    'fred',
    'alex',
    'daniel',
    'rishi',
    'oliver',
    'thomas',
    'male',
    'man',
  };

  /// Get character data for a voice.
  /// Checks injected '_isFemale' marker first (set by _deduplicatedVoices),
  /// then falls back to name-based detection.
  Map<String, dynamic> _charData(Map<Object?, Object?> voice) {
    final locale = voice['locale']?.toString().toLowerCase() ?? '';
    final lang = locale.split('-').first;

    if (lang == 'en') {
      // Prefer the injected marker set during voice pool building
      final forcedFemale = voice['_isFemale'];
      bool isFemale;
      if (forcedFemale != null) {
        isFemale = forcedFemale == true;
      } else {
        final name = voice['name']?.toString().toLowerCase() ?? '';
        final isFemaleByName = _englishFemaleNames.any((n) => name.contains(n));
        final isMaleByName = _englishMaleNames.any((n) => name.contains(n));
        // If name matches female → female. If matches male or neither → male.
        isFemale = isFemaleByName && !isMaleByName;
      }
      return _langCharacters[isFemale ? 'en_f' : 'en']!;
    }
    return _langCharacters[lang] ??
        {'name': 'Voice', 'emoji': '🎙️', 'color': 0xFF9E9E9E};
  }

  /// Priority order for the voice card row.
  /// English Male + Female always first, then top Indian & global languages.
  static const List<String> _voicePriority = [
    'en_m', // English Male
    'en_f', // English Female
    'ta', // Tamil
    'hi', // Hindi
    'te', // Telugu
    'ml', // Malayalam
    'kn', // Kannada
    'bn', // Bengali
    'fr', // French
    'es', // Spanish
  ];

  /// Returns up to 10 curated voices: one per priority slot,
  /// filtered from voices actually available on the device.
  /// For English: takes device voices by INDEX (0 = Male, 1 = Female)
  /// so it works even with code-named Google TTS voices.
  List<Map<Object?, Object?>> _deduplicatedVoices() {
    // Separate English voices from the rest
    final englishVoices = <Map<Object?, Object?>>[];
    final pool = <String, Map<Object?, Object?>>{};

    for (final voice in _voices) {
      final locale = voice['locale']?.toString().toLowerCase() ?? '';
      final lang = locale.split('-').first;
      if (lang == 'en') {
        // Try name-based first
        final name = voice['name']?.toString().toLowerCase() ?? '';
        final femaleByName = _englishFemaleNames.any((n) => name.contains(n));
        final maleByName = _englishMaleNames.any((n) => name.contains(n));
        if (femaleByName && !maleByName) {
          pool.putIfAbsent('en_f', () => voice);
        } else if (maleByName) {
          pool.putIfAbsent('en_m', () => voice);
        } else {
          // Ambiguous name (Google TTS code names) → collect for index fallback
          englishVoices.add(voice);
        }
      } else {
        pool.putIfAbsent(lang, () => voice);
      }
    }

    // Fill missing English slots using index order:
    // first ambiguous voice → Male, second → Female
    if (!pool.containsKey('en_m') && englishVoices.isNotEmpty) {
      final v = Map<Object?, Object?>.from(englishVoices.first);
      v['_isFemale'] = false; // inject gender marker
      pool['en_m'] = v;
      englishVoices.removeAt(0);
    }
    if (!pool.containsKey('en_f') && englishVoices.isNotEmpty) {
      final v = Map<Object?, Object?>.from(englishVoices.first);
      v['_isFemale'] = true; // inject gender marker
      pool['en_f'] = v;
    }

    // Pick voices in priority order (skip missing ones)
    final result = <Map<Object?, Object?>>[];
    for (final key in _voicePriority) {
      if (pool.containsKey(key)) {
        result.add(pool[key]!);
        if (result.length >= 10) break;
      }
    }
    return result;
  }

  /// Get unique languages (one voice per language code)
  List<Map<Object?, Object?>> _getUniqueLanguages() {
    final seen = <String>{};
    final result = <Map<Object?, Object?>>[];
    for (final voice in _voices) {
      final locale = voice['locale']?.toString().toLowerCase() ?? '';
      final lang = locale.split('-').first;
      if (!seen.contains(lang)) {
        seen.add(lang);
        result.add(voice);
      }
    }
    return result;
  }

  Widget _buildSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)]
              : [Colors.grey.shade50, Colors.white],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Read Voice ────────────────────────────────────────────
          if (_voices.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('📖 Voice', isDark),
                _buildLanguagePickerButton(
                  isDark: isDark,
                  isTranslation: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildVoiceRow(
              isDark: isDark,
              selectedVoice: _readVoice,
              isTranslation: false,
            ),
            const SizedBox(height: 14),

            // ── Translation Language ─────────────────────────────────────
            _sectionLabel('🌐 Translation Language', isDark),
            const SizedBox(height: 8),
            _buildLanguagePickerButton(isDark: isDark, isTranslation: true),
            const SizedBox(height: 14),
          ],

          // ── Speed ────────────────────────────────────────────────
          _buildCompactSlider(
            emoji: '⚡',
            label: 'Speed',
            value: _speed,
            displayValue: '${_speed.toStringAsFixed(1)}x',
            min: 0.1,
            max: 1.0,
            onChanged: _changeSpeed,
            color: Colors.blue,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // ── Pitch ────────────────────────────────────────────────
          _buildCompactSlider(
            emoji: '🎵',
            label: 'Pitch',
            value: _pitch,
            displayValue: _pitch.toStringAsFixed(1),
            min: 0.5,
            max: 2.0,
            onChanged: _changePitch,
            color: Colors.purple,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // ── Highlight Color ──────────────────────────────────────
          _sectionLabel('🎨 Highlight', isDark),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildColorDot(Colors.greenAccent),
                _buildColorDot(Colors.yellowAccent),
                _buildColorDot(Colors.orangeAccent),
                _buildColorDot(Colors.cyanAccent),
                _buildColorDot(Colors.pinkAccent),
                _buildColorDot(Colors.purpleAccent),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Builds a compact button that opens a language search dialog.
  Widget _buildLanguagePickerButton({
    required bool isDark,
    bool isTranslation = true,
  }) {
    final primary = Theme.of(context).primaryColor;
    final selectedVoice = isTranslation ? _translationVoice : _readVoice;
    final selectedLocale = selectedVoice?['locale']?.toString() ?? '';
    final selectedLang = selectedLocale.split('-').first.toLowerCase();
    final selectedName =
        _languageNames[selectedLang] ?? selectedLang.toUpperCase();
    final hasSelection = selectedVoice != null;

    return GestureDetector(
      onTap: () => _showLanguageSearchDialog(isTranslation: isTranslation),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasSelection
                ? [primary.withOpacity(0.15), primary.withOpacity(0.05)]
                : isDark
                ? [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ]
                : [Colors.grey.shade100, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasSelection
                ? primary.withOpacity(0.4)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: hasSelection ? 1.5 : 1,
          ),
          boxShadow: hasSelection
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTranslation
                  ? Icons.language_rounded
                  : Icons.record_voice_over_rounded,
              size: 18,
              color: hasSelection
                  ? primary
                  : (isDark ? Colors.white54 : Colors.grey.shade500),
            ),
            const SizedBox(width: 8),
            Text(
              hasSelection
                  ? selectedName
                  : (isTranslation ? 'Choose Language' : 'Search Language'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasSelection
                    ? primary
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.search_rounded,
              size: 15,
              color: hasSelection
                  ? primary.withOpacity(0.7)
                  : (isDark ? Colors.white38 : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a searchable language picker bottom sheet dialog.
  void _showLanguageSearchDialog({bool isTranslation = true}) {
    _langSearchController.clear();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final languages = _getUniqueLanguages();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Filter languages based on search
            final query = _langSearchController.text.toLowerCase();
            final filtered = languages.where((voice) {
              final locale = voice['locale']?.toString().toLowerCase() ?? '';
              final lang = locale.split('-').first;
              final name = (_languageNames[lang] ?? lang).toLowerCase();
              return name.contains(query) || lang.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.language_rounded, color: primary, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Choose Language',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        const Spacer(),
                        if ((isTranslation ? _translationVoice : _readVoice) !=
                            null)
                          GestureDetector(
                            onTap: () {
                              if (isTranslation) {
                                setState(() => _translationVoice = null);
                                _ttsService.setTranslationMode(false);
                                setState(() => _translationModeEnabled = false);
                              } else {
                                setState(() => _readVoice = null);
                                // Default to en-US if cleared
                                _ttsService.setLanguage('en-US');
                              }
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _langSearchController,
                      autofocus: true,
                      onChanged: (_) => setModalState(() {}),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey.shade900,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search language...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: primary.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Language list
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade300,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No languages found',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final voice = filtered[i];
                              final locale = voice['locale']?.toString() ?? '';
                              final langCode = locale
                                  .split('-')
                                  .first
                                  .toLowerCase();
                              final langName =
                                  _languageNames[langCode] ??
                                  langCode.toUpperCase();
                              final char = _charData(voice);
                              final charEmoji = char['emoji'] as String;
                              final charColor = Color(char['color'] as int);

                              final currentSelectedVoice = isTranslation
                                  ? _translationVoice
                                  : _readVoice;
                              final selectedLocale =
                                  currentSelectedVoice?['locale']?.toString() ??
                                  '';
                              final selectedLang = selectedLocale
                                  .split('-')
                                  .first
                                  .toLowerCase();
                              final isSelected = langCode == selectedLang;

                              return GestureDetector(
                                onTap: () {
                                  _changeVoice(
                                    voice,
                                    isTranslation: isTranslation,
                                  );
                                  if (isTranslation &&
                                      !_translationModeEnabled) {
                                    setState(
                                      () => _translationModeEnabled = true,
                                    );
                                    _ttsService.setTranslationMode(true);
                                  }
                                  Navigator.pop(ctx);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isSelected
                                          ? [
                                              charColor.withOpacity(0.2),
                                              charColor.withOpacity(0.08),
                                            ]
                                          : isDark
                                          ? [
                                              Colors.white.withOpacity(0.05),
                                              Colors.white.withOpacity(0.02),
                                            ]
                                          : [Colors.grey.shade50, Colors.white],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? charColor.withOpacity(0.5)
                                          : (isDark
                                                ? Colors.white10
                                                : Colors.grey.shade200),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: charColor.withOpacity(
                                            isSelected ? 0.2 : 0.1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            charEmoji,
                                            style: const TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              langName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? charColor
                                                    : (isDark
                                                          ? Colors.white
                                                          : Colors
                                                                .grey
                                                                .shade800),
                                              ),
                                            ),
                                            Text(
                                              langCode.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.grey.shade400,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: charColor,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Builds a horizontal scrollable row of voice cards.
  /// [isTranslation] = true → tapping sets the translation voice.
  /// [isTranslation] = false → tapping sets the read voice.
  Widget _buildVoiceRow({
    required bool isDark,
    required Map<Object?, Object?>? selectedVoice,
    required bool isTranslation,
  }) {
    final dedupedVoices = _deduplicatedVoices();
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dedupedVoices.length,
        itemBuilder: (context, i) {
          final voice = dedupedVoices[i];
          final isSelected =
              selectedVoice != null &&
              selectedVoice['locale'] == voice['locale'];
          final char = _charData(voice);
          final charName = char['name'] as String;
          final charEmoji = char['emoji'] as String;
          final charColor = Color(char['color'] as int);
          final locale = voice['locale']?.toString() ?? '';
          final langCode = locale.split('-').first.toUpperCase();

          return GestureDetector(
                onTap: () => _changeVoice(voice, isTranslation: isTranslation),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  width: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? [
                              charColor.withOpacity(0.25),
                              charColor.withOpacity(0.10),
                            ]
                          : isDark
                          ? [
                              Colors.white.withOpacity(0.07),
                              Colors.white.withOpacity(0.03),
                            ]
                          : [Colors.white, Colors.grey.shade50],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? charColor
                          : (isDark ? Colors.white12 : Colors.grey.shade200),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: charColor.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: charColor.withOpacity(
                            isSelected ? 0.25 : 0.12,
                          ),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            charEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        charName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? charColor
                              : (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        langCode,
                        style: TextStyle(
                          fontSize: 8,
                          color: isSelected
                              ? charColor.withOpacity(0.8)
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate(target: isSelected ? 1 : 0)
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 200.ms,
              );
        },
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSlider({
    required String emoji,
    required String label,
    required double value,
    required String displayValue,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color.withOpacity(0.8),
            inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade200,
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            trackHeight: 6,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildColorDot(Color color) {
    final bool isSelected = widget.currentHighlightColor.value == color.value;
    return GestureDetector(
      onTap: () {
        if (widget.onHighlightColorChanged != null) {
          widget.onHighlightColorChanged!(color);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        width: isSelected ? 38 : 32,
        height: isSelected ? 38 : 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isSelected ? 0.6 : 0.25),
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}
