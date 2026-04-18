import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';

class SignatureTemplate {
  final String id;
  final String name;
  final String description;
  final SignatureStyle style;

  SignatureTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.style,
  });
}

enum SignatureStyle {
  script, // Cursive/script style
  formal, // Formal business style
  casual, // Casual handwriting
  elegant, // Elegant calligraphy
  modern, // Modern minimalist
  bold, // Bold and strong
}

class SignatureTemplateScreen extends StatefulWidget {
  final Function(Uint8List imageData, String templateId) onSave;

  const SignatureTemplateScreen({super.key, required this.onSave});

  @override
  State<SignatureTemplateScreen> createState() =>
      _SignatureTemplateScreenState();
}

class _SignatureTemplateScreenState extends State<SignatureTemplateScreen> {
  final TextEditingController _nameController = TextEditingController();
  SignatureTemplate? _selectedTemplate;
  Color _selectedColor = Colors.black;

  final List<SignatureTemplate> _templates = [
    SignatureTemplate(
      id: 'script',
      name: 'Script Style',
      description: 'Elegant cursive signature',
      style: SignatureStyle.script,
    ),
    SignatureTemplate(
      id: 'formal',
      name: 'Formal Style',
      description: 'Professional business signature',
      style: SignatureStyle.formal,
    ),
    SignatureTemplate(
      id: 'casual',
      name: 'Casual Style',
      description: 'Relaxed handwriting style',
      style: SignatureStyle.casual,
    ),
    SignatureTemplate(
      id: 'elegant',
      name: 'Elegant Style',
      description: 'Sophisticated calligraphy',
      style: SignatureStyle.elegant,
    ),
    SignatureTemplate(
      id: 'modern',
      name: 'Modern Style',
      description: 'Clean minimalist design',
      style: SignatureStyle.modern,
    ),
    SignatureTemplate(
      id: 'bold',
      name: 'Bold Style',
      description: 'Strong and impactful',
      style: SignatureStyle.bold,
    ),
  ];

  final List<Color> _availableColors = [
    Colors.black,
    Colors.blue,
    const Color(0xFF1976D2), // Dark blue
    const Color(0xFF0D47A1), // Navy
    const Color(0xFF004D40), // Dark teal
    const Color(0xFF1B5E20), // Dark green
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed:
                _selectedTemplate != null && _nameController.text.isNotEmpty
                ? _generateAndSave
                : null,
            tooltip: 'Generate Signature',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name input
            const Text(
              'Your Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.person),
              ),
              onChanged: (value) => setState(() {}),
            ),

            const SizedBox(height: 32),

            // Color selection
            const Text(
              'Signature Color',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Template selection
            const Text(
              'Choose Style',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...(_templates.map((template) {
              final isSelected = _selectedTemplate?.id == template.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isSelected ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _getStyleIcon(template.style),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  title: Text(
                    template.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(template.description),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : const Icon(Icons.circle_outlined),
                  onTap: () {
                    setState(() {
                      _selectedTemplate = template;
                    });
                  },
                ),
              );
            }).toList()),

            const SizedBox(height: 32),

            // Preview
            if (_nameController.text.isNotEmpty && _selectedTemplate != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _nameController.text,
                        style: _getTextStyle(_selectedTemplate!.style),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _selectedTemplate != null && _nameController.text.isNotEmpty
                    ? _generateAndSave
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Signature'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStyleIcon(SignatureStyle style) {
    switch (style) {
      case SignatureStyle.script:
        return '✒️';
      case SignatureStyle.formal:
        return '🖊️';
      case SignatureStyle.casual:
        return '✏️';
      case SignatureStyle.elegant:
        return '🖋️';
      case SignatureStyle.modern:
        return '📝';
      case SignatureStyle.bold:
        return '🖍️';
    }
  }

  TextStyle _getTextStyle(SignatureStyle style) {
    switch (style) {
      case SignatureStyle.script:
        return TextStyle(
          fontFamily: 'Cursive',
          fontSize: 48,
          fontStyle: FontStyle.italic,
          color: _selectedColor,
          fontWeight: FontWeight.w300,
        );
      case SignatureStyle.formal:
        return TextStyle(
          fontFamily: 'Serif',
          fontSize: 42,
          color: _selectedColor,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        );
      case SignatureStyle.casual:
        return TextStyle(
          fontFamily: 'Sans-serif',
          fontSize: 40,
          color: _selectedColor,
          fontWeight: FontWeight.w400,
        );
      case SignatureStyle.elegant:
        return TextStyle(
          fontFamily: 'Serif',
          fontSize: 50,
          fontStyle: FontStyle.italic,
          color: _selectedColor,
          fontWeight: FontWeight.w300,
          letterSpacing: 2.0,
        );
      case SignatureStyle.modern:
        return TextStyle(
          fontFamily: 'Sans-serif',
          fontSize: 38,
          color: _selectedColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.0,
        );
      case SignatureStyle.bold:
        return TextStyle(
          fontFamily: 'Sans-serif',
          fontSize: 44,
          color: _selectedColor,
          fontWeight: FontWeight.w900,
        );
    }
  }

  Future<void> _generateAndSave() async {
    if (_selectedTemplate == null || _nameController.text.isEmpty) return;

    try {
      // Create a widget to render
      final textWidget = RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.all(40),
          color: Colors.transparent,
          child: Text(
            _nameController.text,
            style: _getTextStyle(_selectedTemplate!.style),
          ),
        ),
      );

      // Render to image
      final imageData = await _captureWidget(textWidget);

      if (imageData != null) {
        widget.onSave(imageData, _selectedTemplate!.id);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating signature: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _captureWidget(Widget widget) async {
    final RenderRepaintBoundary boundary = RenderRepaintBoundary();
    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    final RenderView renderView = RenderView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
      configuration: ViewConfiguration.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first,
      ),
    );

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
          container: boundary,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: widget,
          ),
        ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData?.buffer.asUint8List();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
