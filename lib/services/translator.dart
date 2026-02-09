import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key, required String initialText});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final TextEditingController _textController = TextEditingController();
  String _translatedText = '';
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final Map<String, String> _languages = {
    'Detect Language': 'auto',
    'English': 'en',
    'Tamil': 'ta',
    'Hindi': 'hi',
    'Telugu': 'te',
    'Kannada': 'kn',
    'Malayalam': 'ml',
    'Bengali': 'bn',
  };

  final Map<String, TextStyle> _fontMap = {
    'English': GoogleFonts.roboto(fontSize: 20),
    'Tamil': GoogleFonts.notoSansTamil(fontSize: 20),
    'Hindi': GoogleFonts.notoSansDevanagari(fontSize: 20),
    'Telugu': GoogleFonts.notoSansTelugu(fontSize: 20),
    'Kannada': GoogleFonts.notoSansKannada(fontSize: 20),
    'Malayalam': GoogleFonts.notoSansMalayalam(fontSize: 20),
    'Bengali': GoogleFonts.notoSansBengali(fontSize: 20),
    'Detect Language': GoogleFonts.roboto(fontSize: 20),
  };

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Tamil';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestMicPermission();
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      await _speech.initialize();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission required.")),
      );
    }
  }

  Future<void> _translateText() async {
    if (_textController.text.trim().isEmpty) return;

    final translator = GoogleTranslator();
    final translation = await translator.translate(
      _textController.text,
      from: _languages[_sourceLanguage]!,
      to: _languages[_targetLanguage]!,
    );

    setState(() {
      _translatedText = translation.text;
    });
  }

  void _startListening() async {
    if (!_isListening && await _speech.initialize()) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Translator',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Language Dropdowns
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sourceLanguage,
                            isExpanded: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: theme.hintColor,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            items: _languages.keys
                                .map(
                                  (lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _sourceLanguage = val!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.swap_horiz_rounded,
                        color: theme.primaryColor,
                      ),
                      onPressed: _swapLanguages,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _targetLanguage,
                            isExpanded: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: theme.hintColor,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            items: _languages.keys
                                .map(
                                  (lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _targetLanguage = val!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Text Input Field
            TextField(
              controller: _textController,
              maxLines: 6,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Enter text to translate...',
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
                border: theme.inputDecorationTheme.border,
                enabledBorder: theme.inputDecorationTheme.enabledBorder,
                focusedBorder: theme.inputDecorationTheme.focusedBorder,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_textController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _textController.clear();
                            _translatedText = '';
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        _isListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: _isListening ? Colors.red : theme.primaryColor,
                      ),
                      onPressed: _isListening
                          ? _stopListening
                          : _startListening,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Translate Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.translate_rounded),
                label: const Text('Translate Now'),
                onPressed: _translateText,
              ),
            ),
            const SizedBox(height: 24),

            // Translated Output
            if (_translatedText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.05),
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Translation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _translatedText,
                      style:
                          _fontMap[_targetLanguage]?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ) ??
                          TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
