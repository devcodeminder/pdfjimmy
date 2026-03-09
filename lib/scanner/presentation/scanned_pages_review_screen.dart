import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdfjimmy/scanner/scanner_controller.dart';
import 'package:pdfjimmy/scanner/crop/post_scan_crop_screen.dart';
import 'package:pdfjimmy/scanner/enhance/image_processor.dart';
import 'package:pdfjimmy/pdf/pdf_builder.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

// ─── Gaming / Neon Color Palette ─────────────────────────────────────────────
const _bg = Color(0xFF060610);
const _surfaceDark = Color(0xFF0D0D1E);
const _card = Color(0xFF111127);
const _neonCyan = Color(0xFF00F5FF);
const _neonPurple = Color(0xFF9B59FF);
const _neonPink = Color(0xFFFF3CAC);
const _neonGold = Color(0xFFFFD700);
const _neonGreen = Color(0xFF00FF9D);
const _glassWhite = Color(0x14FFFFFF);
const _glassWhiteBorder = Color(0x33FFFFFF);

class ScannedPagesReviewScreen extends StatelessWidget {
  const ScannedPagesReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ScannerController>();

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, controller),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.0,
            colors: [Color(0xFF12103A), _bg],
          ),
        ),
        child: Obx(() {
          if (controller.scannedPages.isEmpty) {
            return _buildEmptyState(controller);
          }
          return Column(
            children: [
              const Gap(kToolbarHeight + 5),
              // Pages Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Obx(
                    () => ReorderableGridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: controller.scannedPages.length,
                      onReorder: (oldIndex, newIndex) {
                        controller.reorderPages(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final imagePath = controller.scannedPages[index];
                        return _PageCard(
                          key: ValueKey(imagePath),
                          imagePath: imagePath,
                          index: index,
                          controller: controller,
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Bottom Action Bar
              _BottomActionBar(controller: controller),
            ],
          );
        }),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ScannerController controller) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_surfaceDark, _surfaceDark.withOpacity(0.9)],
            ),
            border: const Border(
              bottom: BorderSide(color: Color(0x339B59FF), width: 1),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Get.back(),
      ),
      title: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCANNED PAGES',
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            Text(
              '${controller.scannedPages.length} page${controller.scannedPages.length != 1 ? 's' : ''} captured',
              style: GoogleFonts.inter(
                color: _neonCyan.withOpacity(0.8),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Add More
        _AppBarAction(
          icon: Icons.add_a_photo_outlined,
          color: _neonCyan,
          tooltip: 'Add More',
          onTap: () => controller.startScan(navigateToReview: false),
        ),
        // Clear All
        _AppBarAction(
          icon: Icons.delete_sweep_outlined,
          color: _neonPink,
          tooltip: 'Clear All',
          onTap: () => _confirmClearAll(context, controller),
        ),
        const Gap(8),
      ],
    );
  }

  Widget _buildEmptyState(ScannerController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neonPurple.withOpacity(0.08),
                  border: Border.all(
                    color: _neonPurple.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _neonPurple.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.document_scanner,
                  color: _neonPurple,
                  size: 44,
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: 1500.ms,
                curve: Curves.easeInOut,
              ),
          const Gap(24),
          Text(
            'NO PAGES YET',
            style: GoogleFonts.rajdhani(
              color: Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          const Gap(8),
          Text(
            'Start scanning to see your pages here',
            style: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
          ),
          const Gap(32),
          GestureDetector(
            onTap: () => controller.startScan(navigateToReview: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_neonPurple, _neonPink],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _neonPurple.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  const Gap(10),
                  Text(
                    'SCAN NOW',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().scale(delay: 300.ms).fadeIn(),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, ScannerController controller) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _GamingDialog(
        title: 'CLEAR ALL PAGES?',
        message:
            'This will permanently remove all ${controller.scannedPages.length} scanned pages.',
        confirmLabel: 'CLEAR ALL',
        confirmColor: _neonPink,
        icon: Icons.delete_forever_outlined,
        onConfirm: () {
          controller.clearScan();
          Get.back();
        },
      ),
    );
  }
}

// ─── AppBar Action Chip ───────────────────────────────────────────────────────
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _AppBarAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ─── Bottom Action Bar ────────────────────────────────────────────────────────
class _BottomActionBar extends StatelessWidget {
  final ScannerController controller;
  const _BottomActionBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_surfaceDark.withOpacity(0.95), _bg],
        ),
        border: const Border(
          top: BorderSide(color: Color(0x339B59FF), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: _neonPurple.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Obx(
        () => controller.isProcessing.value
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _neonCyan,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const Gap(12),
                      Text(
                        'Processing...',
                        style: GoogleFonts.rajdhani(
                          color: _neonCyan,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BarButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    gradient: [_neonCyan, const Color(0xFF007BFF)],
                    onTap: () => _onShare(context),
                  ),
                  _BarButton(
                    icon: Icons.save_alt_outlined,
                    label: 'Save',
                    gradient: [_neonPurple, _neonPink],
                    onTap: () => _onSave(context),
                    isPrimary: true,
                  ),
                  _BarButton(
                    icon: Icons.compress_outlined,
                    label: 'Compress',
                    gradient: [_neonGold, const Color(0xFFFF8C00)],
                    onTap: () => _onCompress(context),
                  ),
                  _BarButton(
                    icon: Icons.print_outlined,
                    label: 'Print',
                    gradient: [_neonGreen, const Color(0xFF00A36C)],
                    onTap: () => _onPrint(context),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onShare(BuildContext context) async {
    if (controller.scannedPages.isEmpty) return;
    try {
      controller.isProcessing.value = true;
      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/Share_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await PdfBuilder.createPdfFromImages(
        imagePaths: controller.scannedPages.toList(),
        outputPath: outPath,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(outPath)],
          subject: 'Scanned Document',
          text: 'Scanned with PdfJimmy',
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Share failed: $e');
    } finally {
      controller.isProcessing.value = false;
    }
  }

  Future<void> _onSave(BuildContext context) async {
    if (controller.scannedPages.isEmpty) return;
    Get.dialog(
      Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _neonPurple.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _neonPurple, strokeWidth: 2.5),
              const Gap(16),
              Text(
                'Generating title...',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
    final smartTitle = await controller.generateSmartTitle();
    Get.back();

    final nameCtrl = TextEditingController(text: smartTitle);
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _SaveDialog(nameCtrl: nameCtrl, controller: controller),
    );
  }

  Future<void> _onCompress(BuildContext context) async {
    if (controller.scannedPages.isEmpty) return;
    int quality = 60;
    bool isMb = true;
    final TextEditingController customSizeCtrl = TextEditingController();

    // Calculate current total size
    double currentSizeMb = 0;
    for (final path in controller.scannedPages) {
      final f = File(path);
      if (f.existsSync()) {
        currentSizeMb += f.lengthSync() / (1024 * 1024);
      }
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => _GamingDialog(
          title: 'COMPRESS PDF',
          icon: Icons.compress_outlined,
          confirmColor: _neonGold,
          confirmLabel: 'COMPRESS & SAVE',
          onConfirm: () async {
            Get.back();
            double? targetSizeMb;
            if (quality == -1 && customSizeCtrl.text.isNotEmpty) {
              final val = double.tryParse(customSizeCtrl.text) ?? 0;
              targetSizeMb = isMb ? val : val / 1024;
            }
            await _doCompress(quality == -1 ? 60 : quality, targetSizeMb);
          },
          customContent: Column(
            children: [
              Text(
                'Select image quality:',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              ),
              const Gap(16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _QualityChip(
                    label: 'LOW\n40%',
                    selected: quality == 40,
                    colors: [Colors.redAccent, const Color(0xFFFF6B35)],
                    onTap: () {
                      customSizeCtrl.clear();
                      setState(() => quality = 40);
                    },
                  ),
                  const Gap(10),
                  _QualityChip(
                    label: 'MED\n60%',
                    selected: quality == 60,
                    colors: [_neonGold, const Color(0xFFFF8C00)],
                    onTap: () {
                      customSizeCtrl.clear();
                      setState(() => quality = 60);
                    },
                  ),
                  const Gap(10),
                  _QualityChip(
                    label: 'HIGH\n80%',
                    selected: quality == 80,
                    colors: [_neonGreen, const Color(0xFF00A36C)],
                    onTap: () {
                      customSizeCtrl.clear();
                      setState(() => quality = 80);
                    },
                  ),
                ],
              ),
              const Gap(16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OR custom limit:',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildUnitToggle(
                          'KB',
                          !isMb,
                          () => setState(() => isMb = false),
                        ),
                        _buildUnitToggle(
                          'MB',
                          isMb,
                          () => setState(() => isMb = true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: quality == -1
                        ? _neonGold.withOpacity(0.5)
                        : Colors.white24,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: customSizeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.rajdhani(
                    color: const Color.fromARGB(255, 24, 24, 22),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: isMb
                        ? 'Enter MB (e.g. 2.5)'
                        : 'Enter KB (e.g. 500)',
                    hintStyle: GoogleFonts.rajdhani(
                      color: Colors.white24,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      setState(() => quality = -1);
                    } else {
                      setState(() => quality = 60);
                    }
                  },
                ),
              ),
              const Gap(12),
              Text(
                'Current Size: ${currentSizeMb.toStringAsFixed(2)} MB',
                style: GoogleFonts.rajdhani(
                  color: _neonCyan.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _neonGold.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _neonGold : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            color: active ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _doCompress(int quality, [double? targetSizeMb]) async {
    try {
      controller.isProcessing.value = true;
      final List<String> compressed = [];
      for (final path in controller.scannedPages) {
        // As a quick heuristic if a custom target MB was provided:
        // We calculate an estimated target quality by scaling,
        // Or if you want a reliable loop, we can just supply a lower quality
        int finalQuality = quality;
        if (targetSizeMb != null) {
          // Very rough custom heuristic. Real compression to exact KB/MB is iterative.
          final file = File(path);
          if (await file.exists()) {
            final double originalSizeMb = await file.length() / (1024 * 1024);
            if (targetSizeMb < originalSizeMb) {
              final double ratio = targetSizeMb / originalSizeMb;
              finalQuality = (100 * ratio).clamp(10, 90).toInt();
            }
          }
        }

        final cPath = await ImageProcessor.compressImage(
          path,
          quality: finalQuality,
        );
        compressed.add(cPath);
      }
      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          '${dir.path}/Compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await PdfBuilder.createPdfFromImages(
        imagePaths: compressed,
        outputPath: outPath,
      );
      Get.snackbar(
        '⚡ Compressed!',
        'Saved to Documents as PDF',
        backgroundColor: _neonGold.withOpacity(0.9),
        colorText: Colors.black,
        borderRadius: 16,
        margin: const EdgeInsets.all(16),
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.check_circle, color: Colors.black),
      );
    } catch (e) {
      Get.snackbar('Error', 'Compress failed: $e');
    } finally {
      controller.isProcessing.value = false;
    }
  }

  Future<void> _onPrint(BuildContext context) async {
    if (controller.scannedPages.isEmpty) return;
    try {
      controller.isProcessing.value = true;
      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/Print_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await PdfBuilder.createPdfFromImages(
        imagePaths: controller.scannedPages.toList(),
        outputPath: outPath,
      );
      controller.isProcessing.value = false;
      await Printing.layoutPdf(
        onLayout: (_) async => File(outPath).readAsBytesSync(),
        name: 'Scanned Document',
      );
    } catch (e) {
      controller.isProcessing.value = false;
      Get.snackbar('Error', 'Print failed: $e');
    }
  }
}

// ─── Bar Button ───────────────────────────────────────────────────────────────
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isPrimary;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isPrimary ? 64 : 52,
            height: isPrimary ? 64 : 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withOpacity(0.45),
                  blurRadius: isPrimary ? 20 : 14,
                  spreadRadius: isPrimary ? 2 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: isPrimary ? 28 : 22),
          ),
          const Gap(7),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: isPrimary ? gradient.first : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
    );
  }
}

// ─── Quality Chip ─────────────────────────────────────────────────────────────
class _QualityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;

  const _QualityChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: colors)
              : LinearGradient(
                  colors: [
                    colors[0].withOpacity(0.08),
                    colors[1].withOpacity(0.08),
                  ],
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.first : colors.first.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.first.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(
            color: selected ? Colors.white : colors.first,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Gaming Dialog ────────────────────────────────────────────────────────────
class _GamingDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? customContent;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final VoidCallback onConfirm;

  const _GamingDialog({
    required this.title,
    this.message,
    this.customContent,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: confirmColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: confirmColor.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: confirmColor.withOpacity(0.3)),
                ),
                child: Icon(icon, color: confirmColor, size: 28),
              ),
              const Gap(16),
              Text(
                title,
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const Gap(10),
                Text(
                  message!,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              if (customContent != null) ...[const Gap(16), customContent!],
              const Gap(24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _glassWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _glassWhiteBorder),
                        ),
                        child: Text(
                          'CANCEL',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              confirmColor,
                              confirmColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: confirmColor.withOpacity(0.4),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Text(
                          confirmLabel,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack).fadeIn(),
    );
  }
}

// ─── Save Dialog ──────────────────────────────────────────────────────────────
class _SaveDialog extends StatelessWidget {
  final TextEditingController nameCtrl;
  final ScannerController controller;

  const _SaveDialog({required this.nameCtrl, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _neonPurple.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _neonPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _neonPurple.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: _neonPurple,
                      size: 22,
                    ),
                  ),
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAVE AS PDF',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Enter document name',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Gap(20),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  suffixText: '.pdf',
                  suffixStyle: GoogleFonts.inter(
                    color: _neonPurple,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: _glassWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _neonPurple.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _neonPurple, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _glassWhiteBorder),
                  ),
                  labelText: 'Document Name',
                  labelStyle: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ),
              const Gap(24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _glassWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _glassWhiteBorder),
                        ),
                        child: Text(
                          'CANCEL',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (nameCtrl.text.isNotEmpty) {
                          Get.back();
                          await controller.saveAsPdf(nameCtrl.text);
                          Get.back();
                          Get.back();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_neonPurple, _neonPink],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _neonPurple.withOpacity(0.4),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Text(
                          'SAVE',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack).fadeIn(),
    );
  }
}

// ─── Page Card ────────────────────────────────────────────────────────────────
class _PageCard extends StatelessWidget {
  final String imagePath;
  final int index;
  final ScannerController controller;

  const _PageCard({
    super.key,
    required this.imagePath,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: () => _showPageActions(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _neonPurple.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _neonPurple.withOpacity(0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail
                  Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: _card,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white24,
                        size: 48,
                      ),
                    ),
                  ),

                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Page number badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_neonPurple, _neonPink],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonPurple.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              'P${index + 1}',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          // Delete button
                          GestureDetector(
                            onTap: () => controller.removePage(index),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _neonPink.withOpacity(0.8),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _neonPink.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top tag — drag handle indicator
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: const Icon(
                        Icons.drag_indicator,
                        color: Colors.white38,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15, duration: 400.ms, curve: Curves.easeOut);
  }

  void _showPageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(
            top: BorderSide(color: Color(0x339B59FF), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_neonPurple, _neonPink],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_neonPurple, _neonPink],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PAGE ${index + 1}',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const Gap(10),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
            const Gap(16),

            // Preview image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _neonPurple.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  cacheWidth: 400,
                  width: double.infinity,
                ),
              ),
            ),

            const Gap(20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SheetAction(
                  icon: Icons.crop,
                  label: 'Crop',
                  colors: [_neonPurple, _neonPink],
                  onTap: () {
                    Get.back();
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
                  icon: Icons.filter_b_and_w,
                  label: 'B&W',
                  colors: [_neonCyan, const Color(0xFF007BFF)],
                  onTap: () {
                    Get.back();
                    controller.enhancePage(index, FilterType.blackAndWhite);
                  },
                ),
                _SheetAction(
                  icon: Icons.auto_fix_high,
                  label: 'Magic',
                  colors: [_neonGold, const Color(0xFFFF8C00)],
                  onTap: () {
                    Get.back();
                    controller.enhancePage(index, FilterType.magicColor);
                  },
                ),
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  colors: [_neonPink, Colors.redAccent],
                  onTap: () {
                    Get.back();
                    controller.removePage(index);
                  },
                ),
              ],
            ),
          ],
        ),
      ).animate().slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOut),
    );
  }
}

// ─── Sheet Action Button ──────────────────────────────────────────────────────
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(0.4),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Gap(7),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: colors.first,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
