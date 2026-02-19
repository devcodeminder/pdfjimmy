import 'dart:ui';
import 'package:flutter/material.dart';
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
  State<TtsPlayerWidget> createState() => _TtsPlayerWidgetState();
}

class _TtsPlayerWidgetState extends State<TtsPlayerWidget> {
  late final PdfTtsService _ttsService;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _speed = 0.5;
  double _pitch = 1.0;
  List<Map<Object?, Object?>> _voices = [];
  Map<Object?, Object?>? _readVoice; // voice for reading PDF
  Map<Object?, Object?>? _translationVoice; // voice for translation
  bool _showSettings = false;

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

    _ttsService.onPageComplete = (int nextPage, int total) {
      if (mounted) {
        widget.onPageChanged(nextPage);
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
      }
    } catch (e) {
      print('Error converting voice map: $e');
    }
  }

  @override
  void dispose() {
    print('TtsPlayerWidget: Dispose called');
    _ttsService.stop();
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
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade400,
                                  Colors.orange.shade600,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Reader',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      foreground: Paint()
                                        ..shader =
                                            LinearGradient(
                                              colors: [
                                                Theme.of(context).primaryColor,
                                                Theme.of(
                                                  context,
                                                ).primaryColor.withOpacity(0.7),
                                              ],
                                            ).createShader(
                                              const Rect.fromLTWH(
                                                0,
                                                0,
                                                150,
                                                50,
                                              ),
                                            ),
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Page ${widget.currentPage + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
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
                  _buildSettings(),
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
                              Theme.of(context).primaryColor.withOpacity(0.7),
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
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
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
                                  size: 28,
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
                    ),

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

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade300, Colors.grey.shade200],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Colors.white70,
            blurRadius: 8,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        iconSize: size * 0.5,
        color: Colors.grey.shade700,
      ),
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
  };

  /// Get character data for a voice
  Map<String, dynamic> _charData(Map<Object?, Object?> voice) {
    final name = voice['name']?.toString().toLowerCase() ?? '';
    final locale = voice['locale']?.toString().toLowerCase() ?? '';
    final lang = locale.split('-').first;

    if (lang == 'en') {
      final isFemale = _englishFemaleNames.any((n) => name.contains(n));
      return _langCharacters[isFemale ? 'en_f' : 'en']!;
    }
    return _langCharacters[lang] ??
        {'name': 'Voice', 'emoji': '🎙️', 'color': 0xFF9E9E9E};
  }

  /// Deduplicate voices: keep only the first (best) voice per language code.
  List<Map<Object?, Object?>> _deduplicatedVoices() {
    final seen = <String>{};
    final result = <Map<Object?, Object?>>[];
    for (final voice in _voices) {
      final locale = voice['locale']?.toString().toLowerCase() ?? '';
      final lang = locale.split('-').first;
      // For English, also differentiate male/female
      final name = voice['name']?.toString().toLowerCase() ?? '';
      final key = lang == 'en'
          ? (_englishFemaleNames.any((n) => name.contains(n)) ? 'en_f' : 'en_m')
          : lang;
      if (!seen.contains(key)) {
        seen.add(key);
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
            _sectionLabel('📖 Read Voice', isDark),
            const SizedBox(height: 8),
            _buildVoiceRow(
              isDark: isDark,
              selectedVoice: _readVoice,
              isTranslation: false,
            ),
            const SizedBox(height: 14),

            // ── Translation Voice ─────────────────────────────────────
            _sectionLabel('🌐 Translation Voice', isDark),
            const SizedBox(height: 8),
            _buildVoiceRow(
              isDark: isDark,
              selectedVoice: _translationVoice,
              isTranslation: true,
            ),
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
                      color: charColor.withOpacity(isSelected ? 0.25 : 0.12),
                      border: isSelected
                          ? Border.all(
                              color: charColor.withOpacity(0.5),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        charEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    charName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? charColor
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
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
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white60 : Colors.grey.shade600,
        letterSpacing: 0.5,
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
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.15),
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 9,
              elevation: 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            trackHeight: 4,
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
