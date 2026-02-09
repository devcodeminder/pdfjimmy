import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pdf_controller.dart';

class PdfToolbar extends StatefulWidget {
  final Function(int)? onPageChanged;
  final Function(double)? onZoomChanged;

  const PdfToolbar({Key? key, this.onPageChanged, this.onZoomChanged})
    : super(key: key);

  @override
  State<PdfToolbar> createState() => _PdfToolbarState();
}

class _PdfToolbarState extends State<PdfToolbar> {
  final TextEditingController _pageController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PdfController>(
      builder: (context, controller, child) {
        return Container(
          color: Colors.orange[500],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page, color: Colors.white),
                    onPressed: controller.currentPage > 0
                        ? () => controller.goToPage(0)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: controller.currentPage > 0
                        ? controller.previousPage
                        : null,
                  ),
                  GestureDetector(
                    onTap: () => _showPageSelector(controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${controller.currentPage + 1} / ${controller.totalPages}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed:
                        controller.currentPage < controller.totalPages - 1
                        ? controller.nextPage
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page, color: Colors.white),
                    onPressed:
                        controller.currentPage < controller.totalPages - 1
                        ? () => controller.goToPage(controller.totalPages - 1)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Zoom Controls
            ],
          ),
        );
      },
    );
  }

  void _showPageSelector(PdfController controller) {
    _pageController.text = (controller.currentPage + 1).toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Page Number (1-${controller.totalPages})',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                _goToPage(controller, value);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            Slider(
              value: (controller.currentPage + 1).toDouble(),
              min: 1,
              max: controller.totalPages.toDouble(),
              divisions: controller.totalPages > 1
                  ? controller.totalPages - 1
                  : null,
              label: (controller.currentPage + 1).toString(),
              onChanged: (value) {
                final page = value.round();
                _pageController.text = page.toString();
                controller.goToPage(page - 1);
              },
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
              _goToPage(controller, _pageController.text);
              Navigator.pop(context);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _goToPage(PdfController controller, String pageText) {
    final page = int.tryParse(pageText);
    if (page != null && page >= 1 && page <= controller.totalPages) {
      controller.goToPage(page - 1);
      widget.onPageChanged?.call(page);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid page number (1 - ${controller.totalPages})',
          ),
        ),
      );
    }
  }
}
