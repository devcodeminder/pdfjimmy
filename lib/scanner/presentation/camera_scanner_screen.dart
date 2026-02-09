import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Add import
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfjimmy/scanner/scanner_controller.dart';
import 'package:pdfjimmy/scanner/enhance/image_processor.dart'; // Import FilterType
import 'package:gap/gap.dart';
import 'dart:ui'; // For ImageFilter

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  // We'll access the controller to handle logic
  final ScannerController controller = Get.find<ScannerController>();

  @override
  void initState() {
    super.initState();
    // Initialize things if needed, but controller handles most logic
    controller.initializeCamera();
  }

  @override
  void dispose() {
    // Controller disposal is handled by GetX or manually if needed
    // But specific camera disposal might be needed if we want to release it when leaving this screen
    controller.disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Preview
            Obx(() {
              if (!controller.isCameraInitialized.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CameraPreview(controller.cameraController!),
              );
            }),

            // 2. Techy Framing Guide (Custom Painter)
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.65,
                child: CustomPaint(
                  painter: TechyBorderPainter(),
                  child: Stack(
                    // Inner content of the frame
                    children: [
                      // Animated Laser Line
                      Obx(
                        () => controller.isAutoMode.value
                            ? Container(
                                    width: double.infinity,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.cyanAccent.withOpacity(
                                            0.8,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .align(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    duration: const Duration(seconds: 2),
                                    curve: Curves.easeInOutSine,
                                  )
                            : const SizedBox.shrink(),
                      ),

                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Obx(
                            () => controller.isAutoMode.value
                                ? _buildStatusChip("Scanning Document...")
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. New GOOGLE LENS Style Top Bar (Language Selector)
            // Only visible in Translate Mode
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Obx(() {
                if (controller.currentMode.value == ScannerMode.translate) {
                  return Center(child: _buildLanguagePill());
                }
                return const SizedBox.shrink();
              }),
            ),

            // Top Bar Standard
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      // Menu or Back
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    const Row(
                      children: [
                        Icon(
                          Icons.bubble_chart,
                          color: Colors.cyanAccent,
                          size: 20,
                        ), // Logo icon
                        Gap(8),
                        Text(
                          "Scocument AI",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),

            // 4. AI Insights Card (Bottom Overlay)
            // 4. AI Insights Card (Only in Scan Mode)
            Positioned(
              bottom: 120, // Adjusted for new bottom bar
              left: 16,
              right: 16,
              child: Obx(
                () => controller.currentMode.value == ScannerMode.scan
                    ? _buildAiInsightsCard()
                    : const SizedBox.shrink(),
              ),
            ),

            // Mark slider removed - only AI Insights kept

            // 6. Bottom Action Bar (Minimal)
            // 6. Google Lens Style Bottom Action Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildGoogleLensBottomBar(context),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildStatusChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildLanguagePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple),
          const Gap(8),
          Obx(
            () => Text(
              controller.sourceLanguage.value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const Gap(8),
          const Icon(Icons.arrow_forward, size: 16, color: Colors.black54),
          const Gap(8),
          GestureDetector(
            onTap: () {
              Get.bottomSheet(
                Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Gap(16),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Gap(24),
                      const Text(
                        "Translate to",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: controller.supportedLanguages.length,
                          itemBuilder: (context, index) {
                            final code = controller.supportedLanguages.keys
                                .elementAt(index);
                            final name = controller.supportedLanguages[code]!;
                            return ListTile(
                              leading: Obx(
                                () => Icon(
                                  Icons.check,
                                  color:
                                      code ==
                                          controller.targetLanguageCode.value
                                      ? Colors.blueAccent
                                      : Colors.transparent,
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                controller.setTargetLanguage(code);
                                Get.back();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                isScrollControlled: true,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Obx(
                () => Text(
                  controller.targetLanguage.value,
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsCard() {
    // Static for now, can be Obx later
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "AI Insights",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.close, color: Colors.white54, size: 18),
                ],
              ),
              const Gap(8),
              const Text(
                "Invoice from Tech Solutions,\n\$1250.00 due Jan 30.",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Gap(16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    Icons.manage_search,
                    "Identify",
                    Colors.greenAccent,
                    () => controller.scanAndAnalyzeType(),
                  ),
                  _buildActionButton(
                    Icons.theater_comedy,
                    "Redact",
                    Colors.orangeAccent,
                    () => controller.scanForOcr(context),
                  ),
                  _buildActionButton(
                    Icons.gesture,
                    "Handwriting",
                    Colors.purpleAccent,
                    () => controller.scanForHandwriting(),
                  ),
                  _buildActionButton(
                    Icons.chat_bubble_outline,
                    "Chat",
                    Colors.blueAccent,
                    () => controller.scanForOcr(context),
                  ),
                  _buildActionButton(
                    Icons.translate,
                    "Translate",
                    Colors.redAccent,
                    () => controller.scanAndTranslate(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Gap(6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Mark slider (_buildAutoManualSlider) removed permanently

  Widget _buildGoogleLensBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.transparent],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeItem("Scan", ScannerMode.scan),
                const Gap(24),
                _buildModeItem("Translate", ScannerMode.translate),
              ],
            ),
          ),
          const Gap(24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery
              IconButton(
                icon: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                ),
                onPressed: () => controller.pickFromGallery(),
              ),

              // Shutter Button (Dynamic)
              Obx(() {
                final isTranslate =
                    controller.currentMode.value == ScannerMode.translate;
                return GestureDetector(
                  onTap: () {
                    if (isTranslate) {
                      controller.scanAndTranslate();
                    } else {
                      controller.captureImage(context);
                    }
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isTranslate ? Icons.translate : Icons.search,
                          color: isTranslate ? Colors.blueAccent : Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Tools / Filters
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                onPressed: () => _showFilterSelector(context, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeItem(String label, ScannerMode mode) {
    return Obx(() {
      final isSelected = controller.currentMode.value == mode;
      return GestureDetector(
        onTap: () => controller.setScannerMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: isSelected
              ? BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );
    });
  }

  void _showFilterSelector(BuildContext context, ScannerController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              border: const Border(top: BorderSide(color: Colors.white24)),
            ),
            child: Column(
              children: [
                const Gap(8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterOption(
                        label: "Original",
                        icon: Icons.image,
                        isSelected:
                            controller.selectedLiveFilter.value ==
                            FilterType.original,
                        onTap: () {
                          controller.setFilter(FilterType.original);
                          Get.back();
                        },
                      ),
                      const Gap(16),
                      _FilterOption(
                        label: "Magic",
                        icon: Icons.auto_fix_high,
                        isSelected:
                            controller.selectedLiveFilter.value ==
                            FilterType.magicColor,
                        onTap: () {
                          controller.setFilter(FilterType.magicColor);
                          Get.back();
                        },
                      ),
                      const Gap(16),
                      _FilterOption(
                        label: "B&W",
                        icon: Icons.filter_b_and_w,
                        isSelected:
                            controller.selectedLiveFilter.value ==
                            FilterType.blackAndWhite,
                        onTap: () {
                          controller.setFilter(FilterType.blackAndWhite);
                          Get.back();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.deepOrange.withOpacity(0.2)
                  : Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.deepOrange : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.deepOrange : Colors.white,
            ),
          ),
          const Gap(8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.deepOrange : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Techy Grid
class TechyBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint cornerPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // 1. Thin Box
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      paint
        ..color = Colors.cyanAccent.withOpacity(0.3)
        ..strokeWidth = 1,
    );

    // 2. Corners
    double cornerSize = 30;
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 0)
        ..lineTo(cornerSize, 0),
      cornerPaint,
    );
    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerSize),
      cornerPaint,
    );
    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - cornerSize)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - cornerSize, size.height),
      cornerPaint,
    );
    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(cornerSize, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, size.height - cornerSize),
      cornerPaint,
    );

    // 3. Techy Grid Lines (Decor)
    final gridApp = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.1)
      ..strokeWidth = 1;
    // Diagonal lines? Or just a centered crosshair?
    // Let's do a crosshair
    double w = size.width;
    double h = size.height;

    canvas.drawLine(
      Offset(w / 2 - 20, h / 2),
      Offset(w / 2 + 20, h / 2),
      gridApp,
    );
    canvas.drawLine(
      Offset(w / 2, h / 2 - 20),
      Offset(w / 2, h / 2 + 20),
      gridApp,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
