import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:pdfjimmy/scanner/scanner_controller.dart';
import 'package:path_provider/path_provider.dart';

class CustomCropScreen extends StatefulWidget {
  final String imagePath;

  const CustomCropScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<CustomCropScreen> createState() => _CustomCropScreenState();
}

class _CustomCropScreenState extends State<CustomCropScreen> {
  final CropController _cropController = CropController();
  late File _imageFile;
  late Uint8List _imageData;
  bool _isLoaded = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      _imageData = await _imageFile.readAsBytes();
      setState(() {
        _isLoaded = true;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load image: $e');
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060610),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Top right icons just for visual "game" aesthetic
                  Row(
                    children: [
                      Icon(Icons.link, color: Colors.blue.shade400, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '1 device',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dummy battery icon mapping the user image
                      const Icon(
                        Icons.battery_charging_full_rounded,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.signal_cellular_alt_rounded,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Crop Area
            Expanded(
              child: Stack(
                children: [
                  if (_isLoaded)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00FFCC).withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FFCC).withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Crop(
                          image: _imageData,
                          controller: _cropController,
                          onCropped: (result) async {
                            if (result is CropSuccess) {
                              await _saveAndContinue(result.croppedImage);
                            } else if (result is CropFailure) {
                              Get.snackbar('Error', 'Failed to crop image');
                              setState(() => _isProcessing = false);
                            }
                          },
                          // Gaming theme styling for the cropper
                          baseColor: Colors.black,
                          maskColor: Colors.black.withOpacity(0.7),
                          cornerDotBuilder: (size, edgeAlignment) => Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Colors.white, Color(0xFF9B59FF)],
                              ),
                              border: Border.all(
                                color: const Color(0xFF00F5FF),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00F5FF,
                                  ).withOpacity(0.7),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF9B59FF,
                                  ).withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          interactive: true,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00FFCC),
                      ),
                    ),

                  if (_isProcessing)
                    Container(
                      color: Colors.black87,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF9500),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Secondary Tools Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildToolButton(
                    Icons.auto_awesome,
                    'Enhance',
                    isPrimary: true,
                  ),
                  _buildToolButton(Icons.color_lens_outlined, 'Filters'),
                  _buildToolButton(Icons.crop_rotate, 'Crop and rotate'),
                ],
              ),
            ),

            // Bottom Flow Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1E),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border.all(
                  color: const Color(0xFF9B59FF).withOpacity(0.2),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Thumbnail
                    Container(
                      width: 50,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        image: DecorationImage(
                          image: FileImage(_imageFile),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '1',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Add Page Button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.note_add_outlined,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Final Action Bar (Discard vs Next)
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3CAC),
                        side: BorderSide(
                          color: const Color(0xFFFF3CAC).withOpacity(0.5),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'DISCARD',
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F5FF), Color(0xFF9B59FF)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F5FF).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _isProcessing = true);
                          _cropController.crop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'NEXT',
                          style: GoogleFonts.rajdhani(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
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

  Widget _buildToolButton(
    IconData icon,
    String label, {
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary
            ? const Color(0xFF9B59FF).withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: isPrimary
            ? Border.all(color: const Color(0xFF9B59FF), width: 1.5)
            : Border.all(color: Colors.white24, width: 1),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFF9B59FF).withOpacity(0.4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isPrimary ? const Color(0xFF00F5FF) : Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
              color: isPrimary ? const Color(0xFF00F5FF) : Colors.white70,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndContinue(Uint8List croppedImageBytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final String fullPath =
          '${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(fullPath);
      await file.writeAsBytes(croppedImageBytes);

      final ScannerController controller = Get.isRegistered<ScannerController>()
          ? Get.find<ScannerController>()
          : Get.put(ScannerController());

      controller.scannedPages.add(fullPath);

      setState(() => _isProcessing = false);

      // Usually, after 'Next', we go to the ScannedPagesReviewScreen
      // But we will let controller handle the flow, or just route manually:
      Get.offNamed(
        '/review',
      ); // Or however you route to review screen in your app
      // Fallback manual navigation:
      // Get.to(() => const ScannedPagesReviewScreen());
    } catch (e) {
      setState(() => _isProcessing = false);
      Get.snackbar('Error', 'Failed to save cropped image: $e');
    }
  }
}
