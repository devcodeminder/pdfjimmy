import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfjimmy/scanner/presentation/smart_scanner_screen.dart';
import 'package:pdfjimmy/services/dictionary.dart';
import 'package:pdfjimmy/screens/signature_library_screen.dart';
import 'package:pdfjimmy/screens/ai_translation_screen.dart';

import 'package:pdfjimmy/controllers/pdf_controller.dart';
import 'package:pdfjimmy/services/pdf_service.dart';
import 'package:pdfjimmy/services/password_storage_service.dart';
import 'package:pdfjimmy/services/pdf_password_service.dart';
import 'package:pdfjimmy/utils/file_helper.dart';
import 'package:pdfjimmy/models/bookmark_model.dart';
import 'package:pdfjimmy/screens/enhanced_pdf_viewer_screen.dart';
import 'package:pdfjimmy/widgets/password_input_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFabExpanded = false;
  final bool _enableHaptics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Custom Header
                // GAME HUD HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF5722,
                                  ).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'LIBRARY',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: theme.colorScheme.onBackground,
                            ),
                          ).animate().fadeIn(duration: 600.ms).slideX(),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Modern Segmented Tab Bar
                      Container(
                            height: 56,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F2E), // Dark Navy
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                                width: 1,
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF7043),
                                    Color(0xFFFF5722),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF5722,
                                    ).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: const Color(
                                0xFF94A3B8,
                              ), // Slate 400
                              labelStyle: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 1,
                              ),
                              dividerColor: Colors.transparent,
                              overlayColor: MaterialStateProperty.all(
                                Colors.transparent,
                              ),
                              tabs: const [
                                Tab(text: 'RECENT'),
                                Tab(text: 'SAVED'),
                                Tab(text: 'CONFIG'),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildRecentTab(),
                      _buildBookmarksTab(),
                      _buildSettingsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ... rest of stack
        ],
      ),
      floatingActionButton: _buildGameFab(),
    );
  }

  // ...

  Widget _buildRecentTab() {
    return Consumer<PdfController>(
      builder: (context, controller, child) {
        if (controller.recentFiles.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_rounded,
            title: 'No recent files',
            subtitle: 'Tap here or click + to open a document',
            onTap: _pickAndOpenPdf,
          ).animate().fadeIn().scale();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          itemCount: controller.recentFiles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final file = controller.recentFiles[index];
            return _buildFileCard(
                  title: file.fileName,
                  subtitle: 'Last opened: ${_formatDate(file.lastOpened)}',
                  meta: FileHelper.formatFileSize(file.fileSize),
                  icon: Icons.picture_as_pdf_outlined, // Modern icon
                  color: const Color(0xFFFF5722), // Premium Orange
                  onTap: () => _openPdfFile(file.filePath),
                  heroTag: 'filename_${file.filePath}',
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1F2E), // Dark Navy
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        title: const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Remove from History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to remove "${file.fileName}" from recent history?',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        actionsPadding: const EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          24,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Color(0xFFFF5722)),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true)
                      controller.removeRecentFile(file.filePath);
                  },
                )
                .animate()
                .fadeIn(delay: (50 * index).ms)
                .slideX(begin: 0.1, duration: 400.ms);
          },
        );
      },
    );
  }

  Widget _buildBookmarksTab() {
    return Consumer<PdfController>(
      builder: (context, controller, child) {
        return FutureBuilder<List<BookmarkModel>>(
          future: PdfService.instance.getBookmarks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No bookmarks yet',
                subtitle: 'Add bookmarks while reading to see them here',
              ).animate().fadeIn().scale();
            }

            final bookmarks = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              itemCount: bookmarks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return _buildFileCard(
                      title: bookmark.title,
                      subtitle:
                          '${bookmark.fileName} • Page ${bookmark.pageNumber + 1}',
                      meta: _formatDate(bookmark.createdAt),
                      icon: Icons.bookmark_border_rounded,
                      color: const Color(0xFFFF5722),
                      onTap: () => _openBookmark(bookmark),
                    )
                    .animate()
                    .fadeIn(delay: (50 * index).ms)
                    .slideX(begin: 0.1, duration: 400.ms);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFileCard({
    required String title,
    required String subtitle,
    required String meta,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onDelete,
    String? heroTag,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151922), // Deeper Dark for Card
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: Colors.deepOrange.withOpacity(0.1),
          highlightColor: Colors.deepOrange.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container (Game Item Style)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (heroTag != null)
                        Hero(
                          tag: heroTag,
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.bold, // Heavier weight
                                color: Colors.white, // White text
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Colors.grey[400], // Lighter grey
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B), // Darker pill
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          meta,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade400, // Softer red
                      size: 22,
                    ),
                    tooltip: 'Remove',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Consumer<PdfController>(
      builder: (context, controller, child) {
        return ListView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildSettingsSection('Appearance', [
              SwitchListTile(
                title: const Text(
                  'Night Mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Dark theme for comfortable reading'),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.dark_mode_rounded,
                    color: Colors.purple,
                  ),
                ),
                value: controller.isNightMode,
                onChanged: (value) => controller.toggleNightMode(),
              ),
              const SizedBox(height: 16),
            ]),

            const SizedBox(height: 24),
            _buildSettingsSection('Data & Storage', [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_toggle_off_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'Clear History',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Remove all files from Recent list'),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear History'),
                      content: const Text(
                        'This will remove all files from your Recent list. This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await controller.clearAllHistory();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History cleared')),
                      );
                    }
                  }
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsSection('About', [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                  ),
                ),
                title: const Text(
                  'App Version',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('v1.0.0'),
                onTap: () => _showAboutDialog(),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.green,
                  ),
                ),
                title: const Text(
                  'Help & Support',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('FAQ and Contact'),
                onTap: () => _showHelpDialog(),
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Future<void> _pickAndOpenPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        _openPdfFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SmartScannerScreen()),
    );
  }

  void _openDictionary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DictionaryScreen()),
    );
  }

  void _openSignatureLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignatureLibraryScreen()),
    );
  }

  Future<void> _pickAndTranslatePdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AITranslationScreen(
              filePath: result.files.single.path!,
              fileName: result.files.single.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  Future<void> _openPdfFile(String filePath, {int initialPage = 0}) async {
    try {
      String? password;

      // Check if PDF is password protected
      final isProtected = await PdfPasswordService.instance
          .isPdfPasswordProtected(filePath);

      if (isProtected) {
        // Check if we have a saved password
        password = PasswordStorageService.instance.getPassword(filePath);

        if (password == null) {
          // Show password dialog
          final fileName = filePath.split(Platform.pathSeparator).last;
          final passwordData = await showPasswordDialog(
            context: context,
            fileName: fileName,
            showRememberOption: true,
          );

          if (passwordData == null) return; // User cancelled

          final inputPassword = passwordData['password'] as String;
          final remember = passwordData['remember'] as bool;

          // Verify password
          final isValid = await PdfPasswordService.instance.verifyPassword(
            filePath,
            inputPassword,
          );

          if (!isValid) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid password'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          password = inputPassword;

          // Save password if requested
          if (remember) {
            await PasswordStorageService.instance.savePassword(
              filePath,
              password,
            );
          }
        }
      }

      // Open PDF viewer
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedPdfViewerScreen(
              filePath: filePath,
              password: password,
              initialPage: initialPage,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening PDF: $e')));
      }
    }
  }

  void _openBookmark(BookmarkModel bookmark) {
    _openPdfFile(bookmark.filePath, initialPage: bookmark.pageNumber);
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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About PDFJimmy'),
        content: const Text(
          'Premium PDF Reader with bookmarks, search, and annotation features.\n\n'
          'Features:\n'
          '• Smart PDF viewing\n'
          '• Premium annotations\n'
          '• Cloud sync (coming soon)',
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For support, contact: help@pdfjimmy.com\n\n'
          'Tips:\n'
          '• Tap + to scan or open a PDF\n'
          '• Double tap to zoom\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildGameFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabExpanded) ...[
          _buildGameFabItem(Icons.camera_alt_rounded, 'SCAN DOCUMENT', () {
            setState(() => _isFabExpanded = false);
            _openScanner();
          }, color: Colors.deepPurple),
          _buildGameFabItem(Icons.translate_rounded, 'TRANSLATOR', () {
            setState(() => _isFabExpanded = false);
            _pickAndTranslatePdf();
          }, color: Colors.blue),
          _buildGameFabItem(Icons.menu_book_rounded, 'DICTIONARY', () {
            setState(() => _isFabExpanded = false);
            _openDictionary();
          }, color: Colors.teal),
          _buildGameFabItem(Icons.draw_rounded, 'SIGNATURES', () {
            setState(() => _isFabExpanded = false);
            _openSignatureLibrary();
          }, color: Colors.pink),
          _buildGameFabItem(Icons.folder_open_rounded, 'OPEN PDF', () {
            setState(() => _isFabExpanded = false);
            _pickAndOpenPdf();
          }, color: Colors.orange),
          const SizedBox(height: 16),
        ],

        // MAIN "GAMEPAD" BUTTON
        GestureDetector(
          onTap: () {
            if (_enableHaptics) HapticFeedback.mediumImpact();
            setState(() => _isFabExpanded = !_isFabExpanded);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade400, Colors.deepOrange.shade700],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.white38,
                  blurRadius: 10,
                  offset: Offset(-4, -4), // Highlight
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(4, 4), // Shadow
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: AnimatedRotation(
                turns: _isFabExpanded ? 0.375 : 0, // 135 degrees
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 32,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameFabItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Retro Label Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: color,
                letterSpacing: 1.2,
                fontFamily:
                    'Courier', // Monospace font for retro feel if available, else fallback
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Arcade Button
          GestureDetector(
            onTap: () {
              if (_enableHaptics) HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.8), color],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                  const BoxShadow(
                    color: Colors.white38,
                    blurRadius: 5,
                    offset: Offset(-2, -2), // Highlight
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(1, 1),
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
}
