import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdfjimmy/scanner/scanner_controller.dart';
import 'package:pdfjimmy/scanner/enhance/image_processor.dart';
import 'package:pdfjimmy/scanner/crop/post_scan_crop_screen.dart';
import 'package:pdfjimmy/scanner/presentation/camera_scanner_screen.dart';
import 'package:translator/translator.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SmartScannerScreen extends StatelessWidget {
  const SmartScannerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ScannerController controller = Get.put(ScannerController());

    return Scaffold(
      appBar: AppBar(
        // ... (unchanged)
        title: const Text('Smart Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: controller.shareCurrentScan,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Save PDF',
            onPressed: () => _showSaveDialog(context, controller),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isScanning.value || controller.isProcessing.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing...'),
              ],
            ),
          );
        }

        if (controller.scannedPages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                      Icons.document_scanner_outlined,
                      size: 80,
                      color: Colors.grey,
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 1.0,
                      end: 1.05,
                      duration: const Duration(seconds: 2),
                    ) // Breathing effect
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      delay: 2000.ms,
                      duration: 1800.ms,
                    ), // Subtle shimmer

                const SizedBox(height: 16),
                const Text(
                  'No pages scanned yet',
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.to(() => const CameraScannerScreen());
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Scan'),
                    ).animate().fadeIn().scale(delay: 400.ms),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: controller.pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ).animate().fadeIn().scale(delay: 500.ms),
                  ],
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: controller.scannedPages.length,
                onReorder: controller.reorderPages,
                itemBuilder: (context, index) {
                  final imagePath = controller.scannedPages[index];
                  return KeyedSubtree(
                    key: ValueKey(imagePath),
                    child: Card(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: Image.file(
                              File(imagePath),
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                            title: Text('Page ${index + 1}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => controller.removePage(index),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Wrap(
                              alignment: WrapAlignment.spaceAround,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.crop),
                                  tooltip: 'Crop',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostScanCropScreen(
                                          imagePath: imagePath,
                                          onCropSaved: (newPath) {
                                            controller.updatePageWithCrop(
                                              index,
                                              newPath,
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Enhance',
                                  onPressed: () => _showFilterOptions(
                                    context,
                                    controller,
                                    index,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.translate,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Translate',
                                  onPressed: () async {
                                    final text = await controller
                                        .extractTextFromPage(index);
                                    if (text.isNotEmpty &&
                                        text != 'Failed to extract text.') {
                                      _showTranslateOptions(context, text);
                                    } else {
                                      Get.snackbar(
                                        'No Text Found',
                                        'Could not extract text from this page.',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.orange,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.theater_comedy,
                                    color: Colors.orange,
                                  ),
                                  tooltip: 'Redact',
                                  onPressed: () async {
                                    final text = await controller
                                        .extractTextFromPage(index);
                                    if (text.isNotEmpty &&
                                        text != 'Failed to extract text.') {
                                      _showTextResult(
                                        context,
                                        text,
                                        isRedactMode: true,
                                      );
                                    } else {
                                      Get.snackbar(
                                        'No Text Found',
                                        'Could not extract text from this page.',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.orange,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.text_fields),
                                  tooltip: 'Extract Text',
                                  onPressed: () async {
                                    final text = await controller
                                        .extractTextFromPage(index);
                                    if (text.isNotEmpty &&
                                        text != 'Failed to extract text.') {
                                      _showTextResult(context, text);
                                    } else {
                                      Get.snackbar(
                                        'No Text Found',
                                        'Could not extract text from this page.',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.orange,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1, duration: 300.ms),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Launch Custom Camera UI
                        Get.to(() => const CameraScannerScreen());
                      },
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: controller.pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().slideY(
              begin: 1,
              end: 0,
              duration: 500.ms,
              curve: Curves.easeOutQuad,
            ),
          ],
        );
      }),
    );
  }

  void _showFilterOptions(
    BuildContext context,
    ScannerController controller,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enhance Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            Wrap(
              spacing: 16,
              children: [
                _FilterButton(
                  label: 'Original',
                  icon: Icons.image,
                  onTap: () {
                    controller.enhancePage(index, FilterType.original);
                    Get.back();
                  },
                ),
                _FilterButton(
                  label: 'B&W',
                  icon: Icons.filter_b_and_w,
                  onTap: () {
                    controller.enhancePage(index, FilterType.blackAndWhite);
                    Get.back();
                  },
                ),
                _FilterButton(
                  label: 'Magic',
                  icon: Icons.auto_fix_high,
                  onTap: () {
                    controller.enhancePage(index, FilterType.magicColor);
                    Get.back();
                  },
                ),
                _FilterButton(
                  label: 'Gray',
                  icon: Icons.format_color_reset,
                  onTap: () {
                    controller.enhancePage(index, FilterType.grayscale);
                    Get.back();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog(
    BuildContext context,
    ScannerController controller,
  ) async {
    // Show loading while analyzing...
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    final smartTitle = await controller.generateSmartTitle();
    Get.back(); // Close loading

    final TextEditingController nameCtrl = TextEditingController(
      text: smartTitle,
    );

    Get.defaultDialog(
      title: "Save as PDF",
      content: Column(
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              suffixText: '.pdf',
            ),
          ),
        ],
      ),
      textConfirm: "Save",
      textCancel: "Cancel",
      onConfirm: () {
        if (nameCtrl.text.isNotEmpty) {
          controller.saveAsPdf(nameCtrl.text);
          Get.back();
        }
      },
    );
  }

  void _showTranslateOptions(BuildContext context, String text) {
    final languages = {
      'hi': 'Hindi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'gu': 'Gujarati',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'pa': 'Punjabi',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh-cn': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
      'ru': 'Russian',
      'en': 'English',
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Select Translation Language',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: languages.entries.map((entry) {
                  return ListTile(
                    leading: const Icon(Icons.language, color: Colors.blue),
                    title: Text(entry.value),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Get.back();
                      _performTranslation(
                        context,
                        text,
                        entry.key,
                        entry.value,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performTranslation(
    BuildContext context,
    String text,
    String langCode,
    String langName,
  ) async {
    // Show loading
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final translator = GoogleTranslator();

      // Split text into chunks if too long
      const maxChunkSize = 4500;
      final chunks = <String>[];

      for (int i = 0; i < text.length; i += maxChunkSize) {
        final end = (i + maxChunkSize < text.length)
            ? i + maxChunkSize
            : text.length;
        chunks.add(text.substring(i, end));
      }

      // Translate each chunk with retry logic
      final translatedChunks = <String>[];
      for (final chunk in chunks) {
        int retries = 0;
        while (retries < 3) {
          try {
            final translated = await translator.translate(chunk, to: langCode);
            translatedChunks.add(translated.text);

            // Delay to avoid rate limiting
            if (chunks.length > 1) {
              await Future.delayed(const Duration(milliseconds: 1500));
            }
            break;
          } catch (e) {
            retries++;
            if (retries >= 3) rethrow;
            await Future.delayed(Duration(milliseconds: 500 * retries));
          }
        }
      }

      final translatedText = translatedChunks.join(' ');

      if (Get.isDialogOpen ?? false) Get.back();

      // Show translated text
      if (!context.mounted) return;

      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.translate, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('Translated to $langName')),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                translatedText,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: translatedText));
                Get.back();
                Get.snackbar(
                  'Copied',
                  'Translation copied to clipboard',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
            TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        'Translation Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _showTextResult(
    BuildContext context,
    String text, {
    bool isRedactMode = false,
  }) {
    final displayText = isRedactMode
        ? text.replaceAll(RegExp(r'\S'), '█') // Simple visual redaction
        : text;

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              isRedactMode ? Icons.theater_comedy : Icons.text_fields,
              color: isRedactMode ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(isRedactMode ? "Redaction Preview" : "Extracted Text"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              displayText,
              style: isRedactMode ? const TextStyle(letterSpacing: 2) : null,
            ),
          ),
        ),
        actions: [
          if (isRedactMode)
            TextButton(
              onPressed: () {
                Get.back();
                Get.snackbar(
                  "Redaction",
                  "This is a preview of how text would look redacted.",
                );
              },
              child: const Text("Apply Redaction"),
            ),
          TextButton(onPressed: () => Get.back(), child: const Text("Close")),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(backgroundColor: Colors.grey[200]),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
