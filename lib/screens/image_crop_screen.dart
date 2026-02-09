import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:typed_data';

class ImageCropScreen extends StatefulWidget {
  final Uint8List imageData;
  final String imageName;

  const ImageCropScreen({
    super.key,
    required this.imageData,
    required this.imageName,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _cropController = CropController();
  bool _isProcessing = false;
  double? _selectedAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crop Signature',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              onPressed: _isProcessing ? null : _cropImage,
              tooltip: 'Crop & Save',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Crop area with premium frame
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Crop(
                  image: widget.imageData,
                  controller: _cropController,
                  onCropped: (croppedData) {
                    Navigator.pop(context, croppedData);
                  },
                  aspectRatio: _selectedAspectRatio,
                  maskColor: Colors.black.withOpacity(0.7),
                  cornerDotBuilder: (size, edgeAlignment) => Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  baseColor: const Color(0xFF2196F3),
                  interactive: true,
                  fixCropRect: false,
                  willUpdateScale: (newScale) => newScale < 5,
                ),
              ),
            ),
          ),

          // Premium Controls Panel
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Instruction text
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: const Color(0xFF2196F3),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Adjust the crop area to include only your signature',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Aspect ratio buttons
                    Row(
                      children: [
                        _buildAspectRatioButton(
                          icon: Icons.crop_16_9_rounded,
                          label: '16:9',
                          aspectRatio: 16 / 9,
                        ),
                        const SizedBox(width: 8),
                        _buildAspectRatioButton(
                          icon: Icons.crop_3_2_rounded,
                          label: '4:3',
                          aspectRatio: 4 / 3,
                        ),
                        const SizedBox(width: 8),
                        _buildAspectRatioButton(
                          icon: Icons.crop_square_rounded,
                          label: 'Square',
                          aspectRatio: 1,
                        ),
                        const SizedBox(width: 8),
                        _buildAspectRatioButton(
                          icon: Icons.crop_free_rounded,
                          label: 'Free',
                          aspectRatio: null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.close_rounded,
                            label: 'Cancel',
                            color: Colors.white.withOpacity(0.1),
                            textColor: Colors.white.withOpacity(0.7),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildActionButton(
                            icon: _isProcessing
                                ? Icons.hourglass_empty_rounded
                                : Icons.crop_rotate_rounded,
                            label: _isProcessing
                                ? 'Processing...'
                                : 'Crop & Save',
                            color: const Color(0xFF2196F3),
                            textColor: Colors.white,
                            onPressed: _isProcessing ? null : _cropImage,
                            isGradient: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectRatioButton({
    required IconData icon,
    required String label,
    required double? aspectRatio,
  }) {
    final isSelected = _selectedAspectRatio == aspectRatio;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedAspectRatio = aspectRatio;
            _cropController.aspectRatio = aspectRatio;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  )
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback? onPressed,
    bool isGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isGradient
            ? const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isGradient
            ? [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _isProcessing && isGradient
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: textColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isGradient ? Colors.transparent : color,
          foregroundColor: textColor,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _cropImage() {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    _cropController.crop();
  }
}
