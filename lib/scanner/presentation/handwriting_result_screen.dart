import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class HandwritingResultScreen extends StatefulWidget {
  final String imagePath;
  final String extractedText;

  const HandwritingResultScreen({
    super.key,
    required this.imagePath,
    required this.extractedText,
  });

  @override
  State<HandwritingResultScreen> createState() =>
      _HandwritingResultScreenState();
}

class _HandwritingResultScreenState extends State<HandwritingResultScreen> {
  double _splitPosition = 0.5; // 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Handwriting to Text",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const Gap(10),
          _buildToggleHeader(),
          const Gap(20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // "After" (Text) - Bottom Layer (Full width)
                        // Note: We put "After" at bottom, but we probably want "Right" side to be After.
                        // Actually, if we use a clipper for the top layer, the bottom layer shows through.
                        // Let's make the Bottom Layer the "After" (Text) view.
                        _buildAfterView(),

                        // "Before" (Image) - Top Layer, Clipped
                        // Use ClipRect with a custom clipper that clips based on _splitPosition
                        ClipRect(
                          clipper: _SliderClipper(_splitPosition),
                          child: _buildBeforeView(),
                        ),

                        // Slider Line
                        Positioned(
                          left: constraints.maxWidth * _splitPosition - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(1, 0),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Slider Handle
                        Positioned(
                          left: constraints.maxWidth * _splitPosition - 16,
                          bottom: 30, // Handle at bottom
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _splitPosition +=
                                    details.delta.dx / constraints.maxWidth;
                                _splitPosition = _splitPosition.clamp(0.0, 1.0);
                              });
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 5,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.unfold_more_double_outlined, // Arrows
                                size: 18,
                                color: Colors.black87,
                              ),
                            ), // Rotated icon ideally
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50), // Dark blue/grey
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.extractedText));
                  Get.snackbar(
                    "Copied",
                    "Text available on clipboard",
                    snackPosition: SnackPosition.BOTTOM,
                    margin: const EdgeInsets.all(20),
                    backgroundColor: Colors.white,
                    colorText: Colors.black,
                  );
                },
                child: const Text(
                  "Handwriting to Editable Text",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Visual indicator of which side is which
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.8),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
          ),
          child: const Text(
            "Before",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(20),
            ),
            border: Border.all(color: Colors.white12),
          ),
          child: const Text("After", style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildBeforeView() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
    );
  }

  Widget _buildAfterView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF0F4F8), // Light paper-like color
      child: Stack(
        children: [
          // Notebook lines background simulation
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) => Container(
              height: 32,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
            ),
          ),

          // Text
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            child: Text(
              widget.extractedText,
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 18,
                fontFamily: 'Courier', // Monospaced to look technical/typed
                height: 1.75, // Match line height roughly (20 * 1.6 ~= 32)
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double split;

  _SliderClipper(this.split);

  @override
  Rect getClip(Size size) {
    // Return Rect for the LEFT side (Before)
    return Rect.fromLTRB(0, 0, size.width * split, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) => oldClipper.split != split;
}
