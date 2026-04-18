import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import 'package:pdfjimmy/features/scanner/scanner_controller.dart';
import 'package:pdfjimmy/features/scanner/crop/post_scan_crop_screen.dart';
import 'package:pdfjimmy/features/scanner/enhance/image_processor.dart';
import 'package:pdfjimmy/features/scanner/presentation/digitized_text_preview_screen.dart';

const _bg = Color(0xFF060610);
const _surfaceDark = Color(0xFF0D0D1E);
const _neonCyan = Color(0xFF00F5FF);
const _neonPurple = Color(0xFF0280F8);
const _neonPink = Color(0xFFFF3CAC);
const _neonGold = Color(0xFFFFD700);
const _neonGreen = Color(0xFF00FF9D);

class PageEditPreviewScreen extends StatelessWidget {
  final int index;
  
  const PageEditPreviewScreen({
    super.key,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ScannerController>();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'PAGE ${index + 1}',
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: _neonPink),
            onPressed: () {
              controller.removePage(index);
              Get.back();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (index >= controller.scannedPages.length) {
          return Center(
            child: Text(
              "Page deleted",
              style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18),
            ),
          );
        }
        final imagePath = controller.scannedPages[index];

        return controller.isProcessing.value
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _neonCyan),
                    const Gap(16),
                    Text(
                      'PROCESSING...',
                      style: GoogleFonts.rajdhani(color: _neonCyan, fontSize: 16, letterSpacing: 2),
                    ).animate().fade().scale(),
                  ],
                ),
              )
            : InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: 'page_edit_$index',
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
      }),
      bottomNavigationBar: _buildBottomActions(context, controller),
    );
  }

  Widget _buildBottomActions(BuildContext context, ScannerController controller) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: _surfaceDark,
        border: const Border(
          top: BorderSide(color: Color(0x339B59FF), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: _neonPurple.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Obx(() {
        if (index >= controller.scannedPages.length) {
          return const SizedBox.shrink();
        }
        final imagePath = controller.scannedPages[index];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SheetAction(
              icon: Icons.crop,
              label: 'Crop',
              colors: const [_neonPurple, _neonPink],
              onTap: () {
                Get.to(
                  () => PostScanCropScreen(
                    imagePath: imagePath,
                    pageIndex: index,
                    onCropSaved: (newPath) =>
                        controller.updatePageWithCrop(index, newPath),
                  ),
                );
              },
            ),
            _SheetAction(
              icon: Icons.text_fields_rounded,
              label: 'Digitize',
              colors: const [_neonGold, Color(0xFFFF8C00)],
              onTap: () {
                Get.to(
                  () => DigitizedTextPreviewScreen(
                    imagePath: imagePath,
                    onSave: (newPath) =>
                        controller.updatePageWithCrop(index, newPath),
                  ),
                );
              },
            ),
            _SheetAction(
              icon: Icons.filter_b_and_w,
              label: 'B&W',
              colors: const [_neonCyan, Color(0xFF007BFF)],
              onTap: () {
                controller.enhancePage(index, FilterType.blackAndWhite);
              },
            ),
            _SheetAction(
              icon: Icons.auto_fix_high,
              label: 'Magic',
              colors: const [_neonGreen, Color(0xFF00A36C)],
              onTap: () {
                controller.enhancePage(index, FilterType.magicColor);
              },
            ),
          ],
        );
      }),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.colors,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Gap(8),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
