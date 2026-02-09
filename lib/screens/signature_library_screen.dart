import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/signature_data.dart';
import '../providers/signature_provider.dart';
import '../widgets/signature_pad.dart';
import '../screens/signature_template_screen.dart';
import '../screens/image_crop_screen.dart';

import '../screens/signature_view_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_animate/flutter_animate.dart';

class SignatureLibraryScreen extends StatefulWidget {
  final Function(SignatureData)? onSelect;

  const SignatureLibraryScreen({super.key, this.onSelect});

  @override
  State<SignatureLibraryScreen> createState() => _SignatureLibraryScreenState();
}

class _SignatureLibraryScreenState extends State<SignatureLibraryScreen> {
  bool _isGridView = true;
  String _searchQuery = '';
  String _sortBy = 'date'; // date, name, usage

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Signature Library',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: theme.colorScheme.onSurface),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'date', child: Text('Sort by Date')),
              PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              PopupMenuItem(value: 'usage', child: Text('Sort by Usage')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Premium Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search signatures...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
          ).animate().fadeIn().slideY(begin: -0.5),

          // Signature Content
          Expanded(
            child: Consumer<SignatureProvider>(
              builder: (context, provider, child) {
                var signatures = provider.searchSignatures(_searchQuery);
                signatures = provider.sortSignatures(_sortBy);

                if (signatures.isEmpty) {
                  return _buildEmptyState();
                }

                return _isGridView
                    ? _buildGridView(signatures, provider)
                    : _buildListView(signatures, provider);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSignatureDialog(),
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Signature',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.draw_rounded,
              size: 56,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No signatures yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "New Signature" to get started',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildGridView(
    List<SignatureData> signatures,
    SignatureProvider provider,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: signatures.length,
      itemBuilder: (context, index) {
        return _buildSignatureCard(signatures[index], provider)
            .animate()
            .fadeIn(delay: (50 * index).ms)
            .scale(begin: const Offset(0.9, 0.9));
      },
    );
  }

  Widget _buildListView(
    List<SignatureData> signatures,
    SignatureProvider provider,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: signatures.length,
      itemBuilder: (context, index) {
        final signature = signatures[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Image.memory(signature.imageData, fit: BoxFit.contain),
            ),
            title: Text(
              signature.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${signature.type.name} • Used ${signature.usageCount} times',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => _showSignatureOptions(signature, provider),
            ),
            onTap: () => _useSignature(signature, provider),
          ),
        ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.2);
      },
    );
  }

  Widget _buildSignatureCard(
    SignatureData signature,
    SignatureProvider provider,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _useSignature(signature, provider),
          onLongPress: () => _showSignatureOptions(signature, provider),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Hero(
                    tag: 'sig_${signature.id}',
                    child: Image.memory(
                      signature.imageData,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            signature.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (signature.isFavorite)
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${signature.usageCount} uses',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSignatureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Create New Signature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogOption(
              Icons.draw_rounded,
              Colors.blue,
              'Draw Signature',
              'Sketch with your finger',
              () {
                Navigator.pop(context);
                _openSignaturePad();
              },
            ),
            _buildDialogOption(
              Icons.camera_alt_rounded,
              Colors.green,
              'Take Photo',
              'Capture from camera',
              () {
                Navigator.pop(context);
                _importSignature(ImageSource.camera);
              },
            ),
            _buildDialogOption(
              Icons.image_rounded,
              Colors.orange,
              'Gallery',
              'Import from photos',
              () {
                Navigator.pop(context);
                _importSignature(ImageSource.gallery);
              },
            ),
            _buildDialogOption(
              Icons.auto_awesome_rounded,
              Colors.purple,
              'Template',
              'Use stylish presets',
              () {
                Navigator.pop(context);
                _openTemplateScreen();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  void _openTemplateScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignatureTemplateScreen(
          onSave: (imageData, templateId) async {
            final provider = context.read<SignatureProvider>();
            await provider.createTemplateSignature(
              name: 'Template Signature ${provider.signatures.length + 1}',
              imageData: imageData,
              templateId: templateId,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template signature created')),
              );
            }
          },
        ),
      ),
    );
  }

  void _openSignaturePad() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignaturePadWidget(
          onSave: (imageData, color, strokeWidth) async {
            final provider = context.read<SignatureProvider>();
            await provider.createDrawnSignature(
              name: 'Signature ${provider.signatures.length + 1}',
              imageData: imageData,
              strokeColor: color,
              strokeWidth: strokeWidth,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signature saved successfully')),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _importSignature(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null && mounted) {
        final imageData = await File(pickedFile.path).readAsBytes();

        // Open crop screen
        final croppedData = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImageCropScreen(imageData: imageData, imageName: 'Signature'),
          ),
        );

        if (croppedData != null && mounted) {
          final provider = context.read<SignatureProvider>();
          await provider.createImageSignature(
            name: 'Signature ${provider.signatures.length + 1}',
            imageData: croppedData,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Signature imported successfully')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing signature: $e')),
        );
      }
    }
  }

  void _useSignature(SignatureData signature, SignatureProvider provider) {
    if (widget.onSelect != null) {
      provider.incrementUsage(signature.id);
      widget.onSelect!(signature);
      Navigator.pop(context);
    } else {
      // Open signature view screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignatureViewScreen(signature: signature),
        ),
      );
    }
  }

  void _showSignatureOptions(
    SignatureData signature,
    SignatureProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.orange.shade50.withOpacity(0.3)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Handle bar
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),

              // Signature Preview
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Image.memory(
                          signature.imageData,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      signature.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${signature.usageCount} uses',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Options
              _buildPremiumOption(
                icon: signature.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                iconColor: Colors.amber,
                iconBgColor: Colors.amber.shade50,
                title: signature.isFavorite
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
                onTap: () {
                  provider.toggleFavorite(signature.id);
                  Navigator.pop(context);
                },
              ),

              _buildPremiumOption(
                icon: Icons.edit_rounded,
                iconColor: Colors.purple,
                iconBgColor: Colors.purple.shade50,
                title: 'Rename',
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(signature, provider);
                },
              ),

              _buildPremiumOption(
                icon: Icons.copy_rounded,
                iconColor: Colors.green,
                iconBgColor: Colors.green.shade50,
                title: 'Duplicate',
                onTap: () async {
                  await provider.duplicateSignature(signature.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Signature duplicated'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 8),

              _buildPremiumOption(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.red,
                iconBgColor: Colors.red.shade50,
                title: 'Delete',
                titleColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(signature, provider);
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? Colors.grey.shade800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(SignatureData signature, SignatureProvider provider) {
    final controller = TextEditingController(text: signature.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Rename Signature'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Signature Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.renameSignature(signature.id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(SignatureData signature, SignatureProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.red.shade50.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Delete Signature',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Are you sure you want to delete "${signature.name}"? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.deleteSignature(signature.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Signature deleted'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
