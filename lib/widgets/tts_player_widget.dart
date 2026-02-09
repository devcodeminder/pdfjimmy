import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdfjimmy/services/pdf_tts_service.dart';

class TtsPlayerWidget extends StatefulWidget {
  final String filePath;
  final int currentPage;
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
  Map<Object?, Object?>? _selectedVoice;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? PdfTtsService();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await _ttsService.getVoices();

    // Set up highlight callback
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

    if (mounted) {
      setState(() {
        _voices = voices;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _ttsService.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_ttsService.isPaused) {
        await _ttsService.resume();
      } else {
        setState(() => _isLoading = true);
        await _ttsService.readPage(widget.filePath, widget.currentPage + 1);
        setState(() => _isLoading = false);
      }
      setState(() => _isPlaying = true);
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

  void _changeVoice(Map<Object?, Object?>? voice) {
    if (voice != null) {
      setState(() => _selectedVoice = voice);
      try {
        final Map<String, String> voiceMap = {};
        voice.forEach((key, value) {
          if (key != null && value != null) {
            voiceMap[key.toString()] = value.toString();
          }
        });
        _ttsService.setVoice(voiceMap);
      } catch (e) {
        print('Error converting voice map: $e');
      }
    }
  }

  @override
  void dispose() {
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
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
                // Premium Drag Handle
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.3),
                          Theme.of(context).primaryColor.withOpacity(0.6),
                          Theme.of(context).primaryColor.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Premium Header with Gradient
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.1),
                        Theme.of(context).primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade400,
                                  Colors.orange.shade600,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Reader',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
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
                                                200,
                                                70,
                                              ),
                                            ),
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Page ${widget.currentPage + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
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
                  const SizedBox(height: 20),
                  _buildSettings(),
                ],

                const SizedBox(height: 28),

                // Premium Controls with 3D Effect
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.skip_previous_rounded,
                      onPressed: () =>
                          widget.onPageChanged(widget.currentPage - 1),
                      size: 48,
                    ),

                    // Main Play/Pause Button - Premium 3D Style
                    GestureDetector(
                      onTap: _togglePlay,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        height: 80,
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
                            width: 3,
                          ),
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(24),
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
                                  size: 40,
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
                      size: 48,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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

  Widget _buildSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)]
              : [Colors.grey.shade50, Colors.white],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voice Selection
          if (_voices.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.2),
                        Theme.of(context).primaryColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.record_voice_over,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Voice',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.02),
                        ]
                      : [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<Object?, Object?>>(
                  value: _selectedVoice,
                  isExpanded: true,
                  hint: Text(
                    'Select a voice',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF1a1f2e)
                      : Colors.white,
                  items: _voices.map((voice) {
                    return DropdownMenuItem(
                      value: voice,
                      child: Text(
                        voice['name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _changeVoice,
                  icon: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Speed Control
          _buildPremiumSlider(
            icon: Icons.speed_rounded,
            label: 'Speed',
            value: _speed,
            displayValue: '${_speed.toStringAsFixed(1)}x',
            min: 0.1,
            max: 1.0,
            onChanged: _changeSpeed,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),

          // Pitch Control
          _buildPremiumSlider(
            icon: Icons.graphic_eq_rounded,
            label: 'Pitch',
            value: _pitch,
            displayValue: _pitch.toStringAsFixed(1),
            min: 0.5,
            max: 2.0,
            onChanged: _changePitch,
            color: Colors.purple,
          ),

          // Highlight Color Selection
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withOpacity(0.3),
                      Colors.orange.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Highlight Color',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildPremiumColorOption(Colors.greenAccent, 'Green'),
                _buildPremiumColorOption(Colors.yellowAccent, 'Yellow'),
                _buildPremiumColorOption(Colors.orangeAccent, 'Orange'),
                _buildPremiumColorOption(Colors.cyanAccent, 'Cyan'),
                _buildPremiumColorOption(Colors.pinkAccent, 'Pink'),
                _buildPremiumColorOption(Colors.purpleAccent, 'Purple'),
              ],
            ),
          ),

          // Voice Cloning Button
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showVoiceCloningDialog,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.graphic_eq,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Clone Voice (Create Profile)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSlider({
    required IconData icon,
    required String label,
    required double value,
    required String displayValue,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.3), color.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 12,
              elevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            trackHeight: 6,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildPremiumColorOption(Color color, String name) {
    final bool isSelected = widget.currentHighlightColor.value == color.value;

    return GestureDetector(
      onTap: () {
        if (widget.onHighlightColorChanged != null) {
          widget.onHighlightColorChanged!(color);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        width: isSelected ? 55 : 50,
        height: isSelected ? 55 : 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.7)],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isSelected ? 0.6 : 0.3),
              blurRadius: isSelected ? 15 : 8,
              offset: const Offset(0, 4),
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: isSelected
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withOpacity(0.3), Colors.transparent],
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 24,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  void _showVoiceCloningDialog() {
    final nameController = TextEditingController();
    double customPitch = 1.0;
    double customRate = 0.5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Voice Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create a custom voice profile by adjusting tone and speed to match your preference.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name',
                    hintText: 'e.g., My AI Voice',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tone (Pitch)'),
                Slider(
                  value: customPitch,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (v) => setState(() => customPitch = v),
                ),
                const Text('Speed (Rate)'),
                Slider(
                  value: customRate,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (v) => setState(() => customRate = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    _addCustomVoice(
                      nameController.text,
                      customPitch,
                      customRate,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Create Profile'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addCustomVoice(String name, double pitch, double rate) {
    // Determine a base voice (using current selected or default)
    // We add a "custom" tag to it.
    // Since we can't actually CREATE a TTS voice at OS level,
    // we will save this preset in our app state.

    // In a real app with backend, this would upload audio/get a token.

    final customVoiceMap = {
      'name': '🤖 $name (Custom)',
      'locale': 'en-US', // Default
      'isCustom': true,
      'pitch': pitch,
      'rate': rate,
    };

    setState(() {
      _voices.insert(0, customVoiceMap);
      _changeVoice(customVoiceMap);
      _speed = rate;
      _pitch = pitch;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Voice Profile "$name" created!')));
  }

  Widget _buildColorOption(Color color) {
    final bool isSelected = widget.currentHighlightColor.value == color.value;
    return GestureDetector(
      onTap: () {
        if (widget.onHighlightColorChanged != null) {
          widget.onHighlightColorChanged!(color);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, size: 20, color: Theme.of(context).primaryColor)
            : null,
      ),
    );
  }
}
