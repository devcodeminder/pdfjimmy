import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MovableTranslatorWidget extends StatefulWidget {
  final String initialText;
  final Offset initialPosition;
  final VoidCallback onClose;
  final Function(Offset) onPositionChanged;
  final VoidCallback? onTranslateExpanded;

  const MovableTranslatorWidget({
    Key? key,
    required this.initialText,
    required this.initialPosition,
    required this.onClose,
    required this.onPositionChanged,
    this.onTranslateExpanded,
  }) : super(key: key);

  @override
  State<MovableTranslatorWidget> createState() =>
      _MovableTranslatorWidgetState();
}

class _MovableTranslatorWidgetState extends State<MovableTranslatorWidget> {
  late Offset position;
  final GoogleTranslator _translator = GoogleTranslator();
  String _translatedText = 'Translating...';
  String _targetLanguage = 'ta';
  bool _isMinimized = true;

  final Map<String, String> _languages = {
    'af': 'Afrikaans', 'sq': 'Albanian', 'am': 'Amharic', 'ar': 'Arabic', 'hy': 'Armenian',
    'az': 'Azerbaijani', 'eu': 'Basque', 'be': 'Belarusian', 'bn': 'Bengali', 'bs': 'Bosnian',
    'bg': 'Bulgarian', 'ca': 'Catalan', 'ceb': 'Cebuano', 'ny': 'Chichewa', 'zh-cn': 'Chinese (Simplified)',
    'zh-tw': 'Chinese (Traditional)', 'co': 'Corsican', 'hr': 'Croatian', 'cs': 'Czech', 'da': 'Danish',
    'nl': 'Dutch', 'en': 'English', 'eo': 'Esperanto', 'et': 'Estonian', 'tl': 'Filipino',
    'fi': 'Finnish', 'fr': 'French', 'fy': 'Frisian', 'gl': 'Galician', 'ka': 'Georgian',
    'de': 'German', 'el': 'Greek', 'gu': 'Gujarati', 'ht': 'Haitian Creole', 'ha': 'Hausa',
    'haw': 'Hawaiian', 'iw': 'Hebrew', 'hi': 'Hindi', 'hmn': 'Hmong', 'hu': 'Hungarian',
    'is': 'Icelandic', 'ig': 'Igbo', 'id': 'Indonesian', 'ga': 'Irish', 'it': 'Italian',
    'ja': 'Japanese', 'jw': 'Javanese', 'kn': 'Kannada', 'kk': 'Kazakh', 'km': 'Khmer',
    'ko': 'Korean', 'ku': 'Kurdish (Kurmanji)', 'ky': 'Kyrgyz', 'lo': 'Lao', 'la': 'Latin',
    'lv': 'Latvian', 'lt': 'Lithuanian', 'lb': 'Luxembourgish', 'mk': 'Macedonian', 'mg': 'Malagasy',
    'ms': 'Malay', 'ml': 'Malayalam', 'mt': 'Maltese', 'mi': 'Maori', 'mr': 'Marathi',
    'mn': 'Mongolian', 'my': 'Myanmar (Burmese)', 'ne': 'Nepali', 'no': 'Norwegian', 'ps': 'Pashto',
    'fa': 'Persian', 'pl': 'Polish', 'pt': 'Portuguese', 'pa': 'Punjabi', 'ro': 'Romanian',
    'ru': 'Russian', 'sm': 'Samoan', 'gd': 'Scots Gaelic', 'sr': 'Serbian', 'st': 'Sesotho',
    'sn': 'Shona', 'sd': 'Sindhi', 'si': 'Sinhala', 'sk': 'Slovak', 'sl': 'Slovenian',
    'so': 'Somali', 'es': 'Spanish', 'su': 'Sundanese', 'sw': 'Swahili', 'sv': 'Swedish',
    'tg': 'Tajik', 'ta': 'Tamil', 'te': 'Telugu', 'th': 'Thai', 'tr': 'Turkish',
    'uk': 'Ukrainian', 'ur': 'Urdu', 'uz': 'Uzbek', 'vi': 'Vietnamese', 'cy': 'Welsh',
    'xh': 'Xhosa', 'yi': 'Yiddish', 'yo': 'Yoruba', 'zu': 'Zulu',
  };

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
    _translateText(widget.initialText);
  }

  @override
  void didUpdateWidget(covariant MovableTranslatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText) {
      if (_isMinimized) {
        position =
            widget.initialPosition; // Snap back to new selection if minimized
      }
      setState(() {
        _translatedText = 'Translating...';
      });
      _translateText(widget.initialText);
    }
  }

  Future<void> _translateText(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final translation = await _translator.translate(
        text,
        to: _targetLanguage,
      );
      if (mounted) {
        setState(() {
          _translatedText = translation.text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = 'Translation failed';
        });
      }
    }
  }

  Widget _buildMinimized({Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Translate Option
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isMinimized = false);
              widget.onTranslateExpanded?.call();
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: const [
                  Icon(Icons.g_translate_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Translate',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Divider
          Container(
            height: 18,
            width: 1,
            color: Colors.white.withOpacity(0.3),
            margin: const EdgeInsets.symmetric(horizontal: 2),
          ),

          // Search Option
          InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              widget.onTranslateExpanded?.call();
              final query = Uri.encodeComponent(widget.initialText);
              final url = Uri.parse('https://www.google.com/search?q=$query');
              
              try {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Could not launch search: $e');
              }
              
              widget.onClose();
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: const [
                  Icon(Icons.search_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded({Key? key}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: key,
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (Draggable Area)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.g_translate_rounded,
                      size: 18,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AI Translator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Language dropdown
                    DropdownButton<String>(
                      value: _targetLanguage,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _targetLanguage = newValue;
                            _translateText(widget.initialText);
                          });
                        }
                      },
                      items: _languages.entries.map<DropdownMenuItem<String>>((
                        e,
                      ) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isMinimized = true);
                      },
                      child: const Icon(
                        Icons.close_fullscreen_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Area
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Original Text',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.initialText,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Translation',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.teal.withOpacity(0.1)
                            : Colors.teal.withOpacity(0.05),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        _translatedText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            position += details.delta;
          });
          widget.onPositionChanged(position);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _isMinimized
              ? _buildMinimized(key: const ValueKey('min'))
              : _buildExpanded(key: const ValueKey('exp')),
        ),
      ),
    );
  }
}
