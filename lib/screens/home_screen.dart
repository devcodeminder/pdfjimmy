import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfjimmy/services/dictionary.dart';
import 'package:pdfjimmy/screens/signature_library_screen.dart';
import 'package:pdfjimmy/screens/ai_translation_screen.dart';
import 'package:pdfjimmy/scanner/presentation/scanned_pages_review_screen.dart';
import 'package:pdfjimmy/scanner/scanner_controller.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';

import 'package:pdfjimmy/controllers/pdf_controller.dart';
import 'package:pdfjimmy/services/pdf_service.dart';
import 'package:pdfjimmy/services/password_storage_service.dart';
import 'package:pdfjimmy/services/pdf_password_service.dart';
import 'package:pdfjimmy/utils/file_helper.dart';
import 'package:pdfjimmy/models/bookmark_model.dart';
import 'package:pdfjimmy/widgets/password_input_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfjimmy/screens/enhanced_pdf_viewer_screen.dart';

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
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF3B30), Color(0xFFFF9500)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF3B30,
                                  ).withOpacity(0.35),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
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
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .shimmer(duration: 1200.ms, color: Colors.white54)
                              .slideX(
                                begin: -0.2,
                                curve: Curves.easeOutBack,
                                duration: 800.ms,
                              ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Modern Segmented Tab Bar
                      Container(
                            height: 52,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF3B30),
                                    Color(0xFFFF9500),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF3B30,
                                    ).withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: const Color(0xFF94A3B8),
                              labelStyle: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                              unselectedLabelStyle: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
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
                          .fadeIn(delay: 200.ms, duration: 500.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            curve: Curves.easeOutBack,
                            duration: 600.ms,
                          )
                          .moveY(begin: 20, curve: Curves.easeOutBack),
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
                isMultiColorSubtitle: true,
                onTap: _pickAndOpenPdf,
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                curve: Curves.easeOutBack,
                duration: 600.ms,
              );
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
                  color: const Color(0xFFFF3B30), // iOS Red
                  onTap: () => _openPdfFile(file.filePath),
                  heroTag: 'filename_${file.filePath}',
                  onDelete: () {
                    controller.removeRecentFile(file.filePath);
                  },
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  curve: Curves.easeOutBack,
                  duration: 500.ms,
                )
                .moveX(begin: 30, curve: Curves.easeOutBack, duration: 500.ms);
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
                  )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                    duration: 600.ms,
                  );
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
                      color: const Color(0xFFFF3B30),
                      onTap: () => _openBookmark(bookmark),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      curve: Curves.easeOutBack,
                      duration: 500.ms,
                    )
                    .moveX(
                      begin: 30,
                      curve: Curves.easeOutBack,
                      duration: 500.ms,
                    );
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.04)
              : Colors.grey.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: Colors.red.withOpacity(0.1),
          highlightColor: Colors.red.withOpacity(0.05),
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
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.bold, // Heavier weight
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
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
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B),
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
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque, // Ensure hit test
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFFF5252),
                          size: 22,
                        ),
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
    bool isMultiColorSubtitle = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
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
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.1),
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
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              isMultiColorSubtitle
                  ? ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFF3B30),
                          Color(0xFFFF9500),
                          Color(0xFFE040FB),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  : Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildSettingsSection('Appearance', [
                  _buildSettingsTile(
                    title: 'Night Mode',
                    subtitle: 'Dark theme for comfortable reading',
                    icon: Icons.dark_mode_rounded,
                    iconColor: Colors.purple,
                    trailing: Switch.adaptive(
                      value: controller.isNightMode,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        controller.toggleNightMode();
                      },
                      activeColor: const Color(0xFFFF3B30),
                    ),
                    onTap: () => controller.toggleNightMode(),
                  ),
                ])
                .animate()
                .fadeIn(duration: 400.ms)
                .moveY(begin: 20, curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 32),
            _buildSettingsSection('Data & Storage', [
                  _buildSettingsTile(
                    title: 'Clear History',
                    subtitle: 'Remove all files from Recent list',
                    icon: Icons.history_rounded,
                    iconColor: Colors.redAccent,
                    onTap: () => _handleClearHistory(controller),
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 16),
                  _buildSettingsTile(
                    title: 'Reset All Settings',
                    subtitle: 'Restore app to default look',
                    icon: Icons.settings_backup_restore_rounded,
                    iconColor: Colors.orange,
                    onTap: () => _handleResetSettings(controller),
                  ),
                ])
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .moveY(begin: 20, curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 32),
            _buildSettingsSection('Support', [
                  _buildSettingsTile(
                    title: 'Share PDFJimmy',
                    subtitle: 'Tell your friends about the app',
                    icon: Icons.share_rounded,
                    iconColor: Colors.teal,
                    onTap: () => _handleShareApp(),
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 16),
                  _buildSettingsTile(
                    title: 'Help & Support',
                    subtitle: 'Contact developers & FAQ',
                    icon: Icons.help_outline_rounded,
                    iconColor: Colors.greenAccent.shade700,
                    onTap: () => _showHelpDialog(),
                  ),
                ])
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .moveY(begin: 20, curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 32),
            _buildSettingsSection('About', [
                  _buildSettingsTile(
                    title: 'App Version',
                    subtitle: 'v1.0.0 (Premium Build)',
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blueAccent,
                    onTap: () => _showAboutDialog(),
                  ),
                ])
                .animate()
                .fadeIn(duration: 400.ms, delay: 300.ms)
                .moveY(begin: 20, curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 120), // Spacing for FAB
          ],
        );
      },
    );
  }

  // Functional Handlers
  Future<void> _handleClearHistory(PdfController controller) async {
    final confirm = await _showPremiumConfirmDialog(
      title: 'Clear History',
      content:
          'This will remove all files from your Recent list. This action cannot be undone.',
      confirmText: 'Clear All',
      isDestructive: true,
    );
    if (confirm == true) {
      await controller.clearAllHistory();
      if (mounted) _showToast('History cleared successfully');
    }
  }

  Future<void> _handleResetSettings(PdfController controller) async {
    final confirm = await _showPremiumConfirmDialog(
      title: 'Reset Settings',
      content:
          'Restore all theme preferences to defaults? This will not delete your files.',
      confirmText: 'Reset Now',
    );
    if (confirm == true) {
      if (controller.isNightMode) controller.toggleNightMode();
      _showToast('Preferences reset to default');
    }
  }

  void _handleShareApp() {
    Share.share(
      'Check out PDFJimmy - The premium AI-powered PDF Reader with characters! 🚀\nDownload now at: https://pdfjimmy.com',
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  Future<bool?> _showPremiumConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
        ),
        content: Text(
          content,
          style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? Colors.red
                  : Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF151922)
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
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
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (sheetCtx) => _CyberScannerSheet(
        onScan: () {
          Navigator.pop(sheetCtx);
          final controller = Get.isRegistered<ScannerController>()
              ? Get.find<ScannerController>()
              : Get.put(ScannerController());
          controller.scanWithFastPackage();
        },
        onGallery: () async {
          Navigator.pop(sheetCtx);
          final ScannerController controller =
              Get.isRegistered<ScannerController>()
              ? Get.find<ScannerController>()
              : Get.put(ScannerController());
          await controller.pickFromGallery();
          if (controller.scannedPages.isNotEmpty) {
            Get.to(() => const ScannedPagesReviewScreen());
          }
        },
      ),
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
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'help@pdfjimmy.com',
      queryParameters: {'subject': 'Support Request - PDFJimmy v1.0.0'},
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: Colors.green),
            const SizedBox(width: 12),
            Text(
              'Support',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help or found a bug?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Our team is ready to assist you. Click the button below to send us an email directly.',
              style: GoogleFonts.outfit(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(emailLaunchUri);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Email Support',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
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
              }, color: Colors.deepPurple)
              .animate()
              .fade(duration: 200.ms)
              .scale(curve: Curves.easeOutBack)
              .moveY(begin: 20, delay: 0.ms),
          _buildGameFabItem(Icons.translate_rounded, 'TRANSLATOR', () {
                setState(() => _isFabExpanded = false);
                _pickAndTranslatePdf();
              }, color: Colors.blue)
              .animate()
              .fade(duration: 200.ms)
              .scale(curve: Curves.easeOutBack)
              .moveY(begin: 20, delay: 40.ms),
          _buildGameFabItem(Icons.menu_book_rounded, 'DICTIONARY', () {
                setState(() => _isFabExpanded = false);
                _openDictionary();
              }, color: Colors.teal)
              .animate()
              .fade(duration: 200.ms)
              .scale(curve: Curves.easeOutBack)
              .moveY(begin: 20, delay: 80.ms),
          _buildGameFabItem(Icons.draw_rounded, 'SIGNATURES', () {
                setState(() => _isFabExpanded = false);
                _openSignatureLibrary();
              }, color: Colors.pink)
              .animate()
              .fade(duration: 200.ms)
              .scale(curve: Curves.easeOutBack)
              .moveY(begin: 20, delay: 120.ms),
          _buildGameFabItem(Icons.folder_open_rounded, 'OPEN PDF', () {
                setState(() => _isFabExpanded = false);
                _pickAndOpenPdf();
              }, color: Colors.orange)
              .animate()
              .fade(duration: 200.ms)
              .scale(curve: Curves.easeOutBack)
              .moveY(begin: 20, delay: 160.ms),
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
                colors: [Color(0xFFFF3B30), Color(0xFFFF9500)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B30).withOpacity(0.5),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Retro Label Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.black87
                  : Colors.white,
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

// ══════════════════════════════════════════════════════════════════════════════
// CYBER SCANNER SHEET — Ultra Gaming HUD Design
// ══════════════════════════════════════════════════════════════════════════════
class _CyberScannerSheet extends StatefulWidget {
  final VoidCallback onScan;
  final VoidCallback onGallery;
  const _CyberScannerSheet({required this.onScan, required this.onGallery});

  @override
  State<_CyberScannerSheet> createState() => _CyberScannerSheetState();
}

class _CyberScannerSheetState extends State<_CyberScannerSheet>
    with TickerProviderStateMixin {
  late AnimationController _scanLineCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _scanLine;
  late Animation<double> _pulse;
  late Animation<double> _entry;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scanLine = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));
    _pulse = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _entry = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, 60 * (1 - _entry.value)),
        child: Opacity(opacity: _entry.value, child: _buildSheet()),
      ),
    );
  }

  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF06060F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // ── Animated scan-line across the sheet ───────────────────────
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: AnimatedBuilder(
                animation: _scanLine,
                builder: (_, __) => CustomPaint(
                  painter: _ScanLinePainter(progress: _scanLine.value),
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing drag handle
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9B59FF), Color(0xFF00F5FF)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00F5FF,
                          ).withOpacity(_pulse.value * 0.8),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(20),

                // ── HUD Header ──────────────────────────────────────────
                _buildHUDHeader(),
                const Gap(24),

                // ── Action Cards ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _CyberActionCard(
                        label: 'SCAN DOC',
                        sublabel: 'Open Camera',
                        icon: Icons.camera_alt_rounded,
                        primaryColor: const Color(0xFF00F5FF),
                        secondaryColor: const Color(0xFF7B2FBE),
                        onTap: widget.onScan,
                        pulse: _pulse,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: _CyberActionCard(
                        label: 'GALLERY',
                        sublabel: 'From Library',
                        icon: Icons.photo_library_rounded,
                        primaryColor: const Color(0xFFFF3CAC),
                        secondaryColor: const Color(0xFF9B59FF),
                        onTap: widget.onGallery,
                        pulse: _pulse,
                      ),
                    ),
                  ],
                ),
                const Gap(20),

                // ── Security badge ──────────────────────────────────────
                _buildSecurityBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHUDHeader() {
    return Column(
      children: [
        // Cyber border header box
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF9B59FF).withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing LED
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00F5FF),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00F5FF,
                            ).withOpacity(_pulse.value),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(10),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFF9B59FF), Color(0xFF00F5FF)],
                    ).createShader(r),
                    child: Text(
                      'DOCUMENT SCANNER',
                      style: GoogleFonts.rajdhani(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const Gap(10),
                  // Right LED
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF9B59FF),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF9B59FF,
                            ).withOpacity(1.0 - _pulse.value + 0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Cyber corner brackets
            Positioned(
              top: -2,
              left: -2,
              child: _CyberBracket(color: const Color(0xFF00F5FF)),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Transform.scale(
                scaleX: -1,
                child: _CyberBracket(color: const Color(0xFF00F5FF)),
              ),
            ),
            Positioned(
              bottom: -2,
              left: -2,
              child: Transform.scale(
                scaleY: -1,
                child: _CyberBracket(color: const Color(0xFF9B59FF)),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Transform.scale(
                scaleX: -1,
                scaleY: -1,
                child: _CyberBracket(color: const Color(0xFF9B59FF)),
              ),
            ),
          ],
        ),
        const Gap(8),
        Text(
          'SELECT INPUT MODE // SYSTEM READY',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            color: const Color(0xFF00F5FF).withOpacity(0.5),
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: const Color(0xFF00F5FF).withOpacity(0.4),
            size: 12,
          ),
          const Gap(6),
          Text(
            'ENCRYPTED  ·  LOCAL ONLY  ·  ZERO CLOUD',
            style: GoogleFonts.rajdhani(
              color: Colors.white24,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cyber Action Card ──────────────────────────────────────────────────────────
class _CyberActionCard extends StatefulWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;
  final Animation<double> pulse;

  const _CyberActionCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
    required this.pulse,
  });

  @override
  State<_CyberActionCard> createState() => _CyberActionCardState();
}

class _CyberActionCardState extends State<_CyberActionCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: widget.pulse,
        builder: (_, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.primaryColor.withOpacity(
                _pressed ? 0.9 : 0.3 + widget.pulse.value * 0.35,
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(
                  _pressed ? 0.5 : widget.pulse.value * 0.25,
                ),
                blurRadius: _pressed ? 30 : 20,
                spreadRadius: _pressed ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow ring
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(
                          widget.pulse.value * 0.4,
                        ),
                        width: 1,
                      ),
                    ),
                  ),
                  // Inner gradient circle
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.primaryColor.withOpacity(0.25),
                          widget.secondaryColor.withOpacity(0.15),
                        ],
                      ),
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(
                            widget.pulse.value * 0.35,
                          ),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.primaryColor,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const Gap(14),
              // Label
              ShaderMask(
                shaderCallback: (r) => LinearGradient(
                  colors: [widget.primaryColor, Colors.white],
                ).createShader(r),
                child: Text(
                  widget.label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const Gap(3),
              Text(
                widget.sublabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(10),
              // Bottom cyber line
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      widget.primaryColor.withOpacity(
                        0.4 + widget.pulse.value * 0.4,
                      ),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cyber Bracket Widget ───────────────────────────────────────────────────────
class _CyberBracket extends StatelessWidget {
  final Color color;
  const _CyberBracket({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 14),
      painter: _BracketPainter(color: color),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  const _BracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

// ── Scan-Line Painter ─────────────────────────────────────────────────────────
class _ScanLinePainter extends CustomPainter {
  final double progress;
  const _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF00F5FF).withOpacity(0.4),
          const Color(0xFF9B59FF).withOpacity(0.5),
          const Color(0xFF00F5FF).withOpacity(0.4),
          Colors.transparent,
        ],
        stops: const [0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 2, size.width, 4));
    canvas.drawRect(Rect.fromLTWH(0, y - 2, size.width, 4), paint);

    // Glow trail above the line
    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, const Color(0xFF00F5FF).withOpacity(0.04)],
      ).createShader(Rect.fromLTWH(0, y - 60, size.width, 60))
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, y - 60, size.width, 60), trailPaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}
