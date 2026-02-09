import 'package:flutter/material.dart';
import '../models/signature_data.dart';
import 'package:provider/provider.dart';
import '../providers/signature_provider.dart';
import 'signature_editor_screen.dart';
import 'dart:typed_data'; // For Uint8List

class SignatureViewScreen extends StatelessWidget {
  final SignatureData signature;

  const SignatureViewScreen({super.key, required this.signature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<SignatureProvider>(
      builder: (context, provider, child) {
        // Get latest version of signature
        final latestSignature = provider.signatures.firstWhere(
          (s) => s.id == signature.id,
          orElse: () => signature,
        );

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              latestSignature.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => _showInfo(context, latestSignature),
                tooltip: 'Signature Info',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Transform.rotate(
                angle: latestSignature.rotation * 3.14159 / 180,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  decoration: BoxDecoration(
                    // Subtle checkerboard or container to show transparency if needed,
                    // but for premium feel just a nice shadow/container
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Hero(
                    tag: 'sig_${latestSignature.id}',
                    child: Image.memory(
                      latestSignature.imageData,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoChip(
                        icon: Icons.edit_rounded,
                        label: 'EDIT',
                        color: theme.primaryColor,
                        onTap: () =>
                            _editSignature(context, latestSignature, provider),
                      ),
                      if (latestSignature.isFavorite) ...[
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          icon: Icons.star_rounded,
                          label: 'FAVORITE',
                          color: Colors.amber,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pinch to zoom • Drag to pan',
                    style: TextStyle(color: theme.hintColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, SignatureData signature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(signature.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Type', signature.type.name.toUpperCase()),
            _buildInfoRow('Created', _formatDate(signature.createdAt)),
            _buildInfoRow('Usage Count', '${signature.usageCount} times'),
            _buildInfoRow('Rotation', '${signature.rotation.toInt()}°'),
            if (signature.strokeWidth > 0)
              _buildInfoRow(
                'Stroke Width',
                signature.strokeWidth.toStringAsFixed(1),
              ),
            _buildInfoRow('Favorite', signature.isFavorite ? 'Yes' : 'No'),
            if (signature.templateId != null)
              _buildInfoRow('Template ID', signature.templateId!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSignature(
    BuildContext context,
    SignatureData signature,
    SignatureProvider provider,
  ) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SignatureEditorScreen(
          imageData: signature.imageData,
          signatureName: signature.name,
          currentRotation: signature.rotation,
        ),
      ),
    );

    if (result != null && context.mounted) {
      // Update signature with edited data
      provider.updateSignature(
        signature.id,
        imageData: result['imageData'] as Uint8List,
        rotation: result['rotation'] as double,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature updated successfully')),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Just now';
    }
  }
}
