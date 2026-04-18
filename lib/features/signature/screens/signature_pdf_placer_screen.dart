import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdfjimmy/core/models/signature_data.dart';
import 'package:pdfjimmy/features/signature/providers/signature_provider.dart';
import 'package:pdfjimmy/core/services/signed_pdf_service.dart';
import 'package:pdfjimmy/features/signature/screens/signature_library_screen.dart';

// ─── Neon palette (matches scanner review screen) ────────────────────────────
const _bg = Color(0xFF060610);
const _surfaceDark = Color(0xFF0D0D1E);
const _card = Color(0xFF111127);
const _neonCyan = Color(0xFF00F5FF);
const _neonPurple = Color(0xFF0280F8);
const _neonPink = Color(0xFFFF3CAC);
const _neonGold = Color(0xFFFFD700);
const _neonGreen = Color(0xFF00FF9D);
const _glassWhite = Color(0x14FFFFFF);
const _glassWhiteBorder = Color(0x33FFFFFF);

// ─── Draggable signature overlay data ────────────────────────────────────────
class _SigOverlay {
  Offset position;
  double scale;
  SignatureData sig;

  _SigOverlay({
    required this.position,
    required this.scale,
    required this.sig,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class SignaturePdfPlacerScreen extends StatefulWidget {
  /// If provided, we skip the PDF pick step and start with this file.
  final String? initialPdfPath;

  const SignaturePdfPlacerScreen({super.key, this.initialPdfPath});

  @override
  State<SignaturePdfPlacerScreen> createState() =>
      _SignaturePdfPlacerScreenState();
}

class _SignaturePdfPlacerScreenState extends State<SignaturePdfPlacerScreen> {
  // ── PDF state ──────────────────────────────────────────────────────────────
  String? _pdfPath;
  String _pdfName = '';
  int _currentPage = 1;
  int _totalPages = 1;
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey _pdfKey = GlobalKey();

  // ── Viewer widget size tracking ────────────────────────────────────────────
  final GlobalKey _viewerContainerKey = GlobalKey();
  Size _viewerSize = const Size(400, 600);

  // ── Signature overlays ─────────────────────────────────────────────────────
  final List<_SigOverlay> _overlays = [];

  // ── Processing ─────────────────────────────────────────────────────────────
  bool _isSaving = false;


  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null) {
      _pdfPath = widget.initialPdfPath;
      _pdfName = p.basename(_pdfPath!);
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  // ── PDF pick ───────────────────────────────────────────────────────────────
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF to Sign',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfPath = result.files.single.path!;
        _pdfName = result.files.single.name;
        _overlays.clear();
        _currentPage = 1;
      });
    }
  }

  // ── Add signature from library ─────────────────────────────────────────────
  void _addSignature() {
    final provider = context.read<SignatureProvider>();
    if (provider.signatures.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignatureLibraryScreen()),
      );
      _showInfo('Create a signature first to place it on the PDF.');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SignaturePickerSheet(
        signatures: provider.signatures,
        onPicked: (sig) {
          Navigator.pop(context);
          setState(() {
            _overlays.add(
              _SigOverlay(
                position: Offset(_viewerSize.width / 2 - 75,
                    _viewerSize.height / 2 - 50),
                scale: 1.0,
                sig: sig,
              ),
            );
          });
        },
      ),
    );
  }

  // ── Update viewer size ─────────────────────────────────────────────────────
  void _updateViewerSize() {
    final box = _viewerContainerKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (box != null && box.hasSize) {
      setState(() => _viewerSize = box.size);
    }
  }

  // ── Save logic ─────────────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (_pdfPath == null) return;
    if (_overlays.isEmpty) {
      _showInfo('Add at least one signature before saving.');
      return;
    }
    _showSaveOptionsDialog();
  }

  Future<void> _doSave({
    required String fileName,
    required String saveDirectory,
  }) async {
    setState(() => _isSaving = true);
    try {
      // 1. Load original PDF bytes
      final originalBytes = await File(_pdfPath!).readAsBytes();

      // 2. Open with Syncfusion PDF
      final document = sf.PdfDocument(inputBytes: originalBytes);

      // 3. Embed each overlay on the correct page
      for (final overlay in _overlays) {
        final pageIndex = _currentPage - 1; // 0-based
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;

        final page = document.pages[pageIndex];
        final pageSize = page.size;

        // Map overlay position from viewer coords → PDF coords
        final scaleX = pageSize.width / _viewerSize.width;
        final scaleY = pageSize.height / _viewerSize.height;

        final sigW = 150.0 * overlay.scale * scaleX;
        final sigH = 100.0 * overlay.scale * scaleY;
        final pdfX = overlay.position.dx * scaleX;
        final pdfY = overlay.position.dy * scaleY;

        // Draw image
        final image = sf.PdfBitmap(overlay.sig.imageData);
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(pdfX, pdfY, sigW, sigH),
        );
      }

      // 4. Save PDF bytes
      final savedBytes = await document.save();
      document.dispose();

      // 5. Write file
      final safeName =
          fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
      final dir = Directory(saveDirectory);
      if (!dir.existsSync()) await dir.create(recursive: true);
      final outPath = p.join(saveDirectory, safeName);
      await File(outPath).writeAsBytes(savedBytes);

      // 6. Track signed PDF locally
      await SignedPdfService.instance.addSignedPdf(
        originalPath: _pdfPath!,
        signedPath: outPath,
        fileName: safeName,
      );

      _showSuccess('✅ Signed PDF saved!\n$outPath');
    } catch (e) {
      _showInfo('Save failed: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Save Options Dialog ────────────────────────────────────────────────────
  void _showSaveOptionsDialog() {
    final nameCtrl = TextEditingController(
      text: 'Signed_${p.basenameWithoutExtension(_pdfName)}',
    );
    String? saveDir;
    bool pickingDir = false;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surfaceDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _neonPurple.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _neonPurple.withValues(alpha: 0.2),
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
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _neonPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _neonPurple.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.save_alt_outlined,
                            color: _neonPurple, size: 22),
                      ),
                      const Gap(12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SAVE SIGNED PDF',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              )),
                          Text('Choose name & location',
                              style: GoogleFonts.inter(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const Gap(20),

                  // File name
                  Text('FILE NAME',
                      style: GoogleFonts.rajdhani(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                  const Gap(8),
                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      suffixText: '.pdf',
                      suffixStyle: GoogleFonts.inter(
                          color: _neonPurple, fontSize: 14),
                      filled: true,
                      fillColor: _glassWhite,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      hintText: 'Signed document name',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.white24, fontSize: 13),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _glassWhiteBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: _neonPurple, width: 1.5),
                      ),
                    ),
                  ),
                  const Gap(20),

                  // Save location
                  Text('SAVE LOCATION',
                      style: GoogleFonts.rajdhani(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                  const Gap(8),
                  GestureDetector(
                    onTap: pickingDir
                        ? null
                        : () async {
                            setDlgState(() => pickingDir = true);
                            final result = await FilePicker.platform
                                .getDirectoryPath(
                                    dialogTitle: 'Choose save location');
                            setDlgState(() {
                              if (result != null) saveDir = result;
                              pickingDir = false;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _glassWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: saveDir != null
                              ? _neonGreen.withValues(alpha: 0.5)
                              : _glassWhiteBorder,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          pickingDir
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _neonCyan,
                                  ))
                              : Icon(
                                  saveDir != null
                                      ? Icons.folder_open
                                      : Icons.folder_outlined,
                                  color: saveDir != null
                                      ? _neonGreen
                                      : Colors.white38,
                                  size: 20),
                          const Gap(12),
                          Expanded(
                            child: Text(
                              saveDir != null
                                  ? _truncatePath(saveDir!)
                                  : 'Tap to choose folder…',
                              style: GoogleFonts.inter(
                                color: saveDir != null
                                    ? Colors.white70
                                    : Colors.white30,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.white24, size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (saveDir == null) ...[
                    const Gap(6),
                    Row(children: [
                      const Icon(Icons.info_outline,
                          color: _neonGold, size: 13),
                      const Gap(5),
                      Text('No folder chosen – saves to Documents',
                          style: GoogleFonts.inter(
                              color: _neonGold.withValues(alpha: 0.7),
                              fontSize: 11)),
                    ]),
                  ],
                  const Gap(24),

                  // Buttons
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _glassWhite,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: _glassWhiteBorder),
                          ),
                          child: Text('CANCEL',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.rajdhani(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 1.5)),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          Navigator.pop(ctx);
                          String dir = saveDir ??
                              (await getApplicationDocumentsDirectory())
                                  .path;
                          await _doSave(
                              fileName: name, saveDirectory: dir);
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_neonPurple, _neonPink]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _neonPurple.withValues(alpha: 0.4),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Text('SAVE',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.rajdhani(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 1.5)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack).fadeIn(),
        ),
      ),
    );
  }

  String _truncatePath(String path) {
    const maxLen = 36;
    if (path.length <= maxLen) return path;
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length >= 3) {
      return '.../${parts[parts.length - 2]}/${parts.last}';
    }
    return '...${path.substring(path.length - maxLen)}';
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF00A36C),
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.0,
            colors: [Color(0xFF12103A), _bg],
          ),
        ),
        child: _pdfPath == null ? _buildPickPdfState() : _buildEditorState(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_surfaceDark, _surfaceDark.withValues(alpha: 0.9)],
            ),
            border: const Border(
                bottom: BorderSide(color: Color(0x339B59FF), width: 1)),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SIGN PDF',
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3)),
          Text(
            _pdfPath == null ? 'Choose a PDF to sign' : _pdfName,
            style: GoogleFonts.inter(
                color: _neonCyan.withValues(alpha: 0.8), fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        if (_pdfPath != null) ...[
          // View signed PDFs
          _AppBarBtn(
            icon: Icons.history_rounded,
            color: _neonGold,
            tooltip: 'Signed PDFs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SignedPdfsListScreen()),
            ),
          ),
          const Gap(4),
          // Manage signatures
          _AppBarBtn(
            icon: Icons.draw_rounded,
            color: _neonPink,
            tooltip: 'Manage Signatures',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SignatureLibraryScreen()),
            ),
          ),
          const Gap(4),
        ],
      ],
    );
  }

  // ── Pick PDF state ─────────────────────────────────────────────────────────
  Widget _buildPickPdfState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neonPurple.withValues(alpha: 0.08),
                  border: Border.all(
                      color: _neonPurple.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: _neonPurple.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5),
                  ],
                ),
                child: const Icon(Icons.picture_as_pdf,
                    color: _neonPurple, size: 50),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 1500.ms,
                  curve: Curves.easeInOut),
          const Gap(28),
          Text('SELECT A PDF',
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4)),
          const Gap(8),
          Text('Choose a PDF file to place your signature on',
              style:
                  GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
          const Gap(32),
          GestureDetector(
            onTap: _pickPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_neonPurple, _neonPink]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: _neonPurple.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open_rounded,
                      color: Colors.white, size: 20),
                  const Gap(10),
                  Text('BROWSE PDF',
                      style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ).animate().scale(delay: 300.ms).fadeIn(),
          const Gap(16),
          // View signed PDFs shortcut
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SignedPdfsListScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _glassWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _glassWhiteBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded,
                      color: _neonGold, size: 18),
                  const Gap(8),
                  Text('View Signed PDFs',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),
          const Gap(12),
          // Manage signatures shortcut
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SignatureLibraryScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _glassWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _glassWhiteBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.draw_rounded,
                      color: _neonPink, size: 18),
                  const Gap(8),
                  Text('Manage Signatures Library',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  // ── Editor state ───────────────────────────────────────────────────────────
  Widget _buildEditorState() {
    return Column(
      children: [
        const Gap(kToolbarHeight + 12),

        // Page navigation info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Page $_currentPage of $_totalPages',
                  style: GoogleFonts.rajdhani(
                      color: _neonCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              Row(
                children: [
                  _NavBtn(
                    icon: Icons.chevron_left,
                    onTap: _currentPage > 1
                        ? () {
                            _pdfController.previousPage();
                          }
                        : null,
                  ),
                  const Gap(8),
                  _NavBtn(
                    icon: Icons.chevron_right,
                    onTap: _currentPage < _totalPages
                        ? () {
                            _pdfController.nextPage();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(8),

        // PDF Viewer + signature overlay
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: _viewerContainerKey,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _neonPurple.withValues(alpha: 0.25), width: 1),
                ),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _updateViewerSize());
                    return Stack(
                      children: [
                        // PDF Viewer
                        SfPdfViewer.file(
                          File(_pdfPath!),
                          key: _pdfKey,
                          controller: _pdfController,
                          enableDoubleTapZooming: false,
                          canShowScrollHead: false,
                          canShowPaginationDialog: false,
                          onPageChanged: (details) {
                            setState(() {
                              _currentPage = details.newPageNumber;
                            });
                          },
                          onDocumentLoaded: (details) {
                            setState(() =>
                                _totalPages = details.document.pages.count);
                          },
                        ),

                        // Signature Overlays
                        ..._overlays.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ov = entry.value;
                          return _DraggableSignature(
                            key: ValueKey('sig_$idx'),
                            overlay: ov,
                            index: idx,
                            onPositionChanged: (np) {
                              setState(() => ov.position = np);
                            },
                            onScaleChanged: (ns) {
                              setState(() => ov.scale = ns);
                            },
                            onDelete: () {
                              setState(() => _overlays.removeAt(idx));
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Bottom bar
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_surfaceDark.withValues(alpha: 0.95), _bg],
        ),
        border: const Border(
            top: BorderSide(color: Color(0x339B59FF), width: 1)),
        boxShadow: [
          BoxShadow(
              color: _neonPurple.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4)),
        ],
      ),
      child: _isSaving
          ? Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: _neonCyan, strokeWidth: 2.5)),
                  const Gap(12),
                  Text('Embedding signature…',
                      style: GoogleFonts.rajdhani(
                          color: _neonCyan, fontSize: 14, letterSpacing: 2)),
                ],
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BarBtn(
                  icon: Icons.folder_open_rounded,
                  label: 'Change PDF',
                  gradient: [_neonCyan, const Color(0xFF007BFF)],
                  onTap: _pickPdf,
                ),
                _BarBtn(
                  icon: Icons.draw_rounded,
                  label: 'Add Sig',
                  gradient: [_neonPurple, _neonPink],
                  onTap: _addSignature,
                  isPrimary: true,
                ),
                _BarBtn(
                  icon: Icons.history_rounded,
                  label: 'Signed',
                  gradient: [_neonGold, const Color(0xFFFF8C00)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignedPdfsListScreen()),
                  ),
                ),
                _BarBtn(
                  icon: Icons.save_alt_outlined,
                  label: 'Save',
                  gradient: [_neonGreen, const Color(0xFF00A36C)],
                  onTap: _onSave,
                ),
              ],
            ),
    );
  }
}

// ─── Draggable Signature Widget ───────────────────────────────────────────────
class _DraggableSignature extends StatefulWidget {
  final _SigOverlay overlay;
  final int index;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback onDelete;

  const _DraggableSignature({
    super.key,
    required this.overlay,
    required this.index,
    required this.onPositionChanged,
    required this.onScaleChanged,
    required this.onDelete,
  });

  @override
  State<_DraggableSignature> createState() => _DraggableSignatureState();
}

class _DraggableSignatureState extends State<_DraggableSignature> {
  double? _baseScale;
  bool _selected = true;

  @override
  Widget build(BuildContext context) {
    final ov = widget.overlay;
    final w = 150.0 * ov.scale;
    final h = 100.0 * ov.scale;

    return Positioned(
      left: ov.position.dx,
      top: ov.position.dy,
      child: GestureDetector(
        onTap: () => setState(() => _selected = !_selected),
        // Use onScale* for BOTH drag and pinch-to-resize.
        // Flutter forbids mixing onPanUpdate with onScale* on the same GestureDetector.
        // focalPointDelta gives finger translation (works for single-finger drag too).
        onScaleStart: (d) => _baseScale = ov.scale,
        onScaleUpdate: (d) {
          // Drag: move by how much the focal point moved
          widget.onPositionChanged(ov.position + d.focalPointDelta);
          // Scale: only update when actually pinching (scale != 1.0)
          if (_baseScale != null && d.scale != 1.0) {
            widget.onScaleChanged((_baseScale! * d.scale).clamp(0.3, 4.0));
          }
        },
        onScaleEnd: (_) => _baseScale = null,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  border: _selected
                      ? Border.all(color: _neonCyan, width: 1.5)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(
                  ov.sig.imageData,
                  fit: BoxFit.contain,
                ),
              ),
              if (_selected)
                Positioned(
                  top: -10,
                  right: -10,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                          color: _neonPink, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Signature picker bottom sheet ───────────────────────────────────────────
class _SignaturePickerSheet extends StatelessWidget {
  final List<SignatureData> signatures;
  final ValueChanged<SignatureData> onPicked;

  const _SignaturePickerSheet(
      {required this.signatures, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x339B59FF), width: 1)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3)),
            ),
            const Gap(16),
            Text('CHOOSE SIGNATURE',
                style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3)),
            const Gap(16),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: signatures.length,
                separatorBuilder: (_, __) => const Gap(12),
                itemBuilder: (_, i) {
                  final sig = signatures[i];
                  return GestureDetector(
                    onTap: () => onPicked(sig),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _neonPurple.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.memory(sig.imageData,
                                    fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          const Gap(8),
                          Text(sig.name,
                              style: GoogleFonts.inter(
                                  color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * i).ms).scale(
                        begin: const Offset(0.9, 0.9),
                        curve: Curves.easeOutBack,
                      );
                },
              ),
            ),
            const Gap(20),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _AppBarBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? _neonPurple.withValues(alpha: 0.15)
              : _glassWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: onTap != null
                ? _neonPurple.withValues(alpha: 0.4)
                : _glassWhiteBorder,
          ),
        ),
        child: Icon(icon,
            color: onTap != null ? _neonPurple : Colors.white24,
            size: 22),
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isPrimary;

  const _BarBtn({
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
          Container(
            width: isPrimary ? 60 : 50,
            height: isPrimary ? 60 : 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.45),
                  blurRadius: isPrimary ? 20 : 14,
                  spreadRadius: isPrimary ? 2 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon,
                color: Colors.white, size: isPrimary ? 26 : 20),
          ),
          const Gap(6),
          Text(label,
              style: GoogleFonts.rajdhani(
                  color: isPrimary ? gradient.first : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ],
      ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.2),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIGNED PDFs LIST SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class SignedPdfsListScreen extends StatefulWidget {
  const SignedPdfsListScreen({super.key});

  @override
  State<SignedPdfsListScreen> createState() => _SignedPdfsListScreenState();
}

class _SignedPdfsListScreenState extends State<SignedPdfsListScreen> {
  List<SignedPdfEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await SignedPdfService.instance.getAll();
    setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_surfaceDark, _surfaceDark.withValues(alpha: 0.9)],
              ),
              border: const Border(
                  bottom: BorderSide(color: Color(0x339B59FF), width: 1)),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('SIGNED PDFs',
            style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 3)),
      ),
      body: _entries.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                return _SignedPdfCard(
                  entry: e,
                  onDelete: () async {
                    await SignedPdfService.instance.removeEntry(e.id);
                    _load();
                  },
                )
                    .animate()
                    .fadeIn(delay: (50 * i).ms)
                    .slideX(begin: 0.15, curve: Curves.easeOut);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _neonGold.withValues(alpha: 0.08),
              border:
                  Border.all(color: _neonGold.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(Icons.history_rounded,
                color: _neonGold, size: 42),
          ),
          const Gap(20),
          Text('NO SIGNED PDFs YET',
              style: GoogleFonts.rajdhani(
                  color: Colors.white54,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3)),
          const Gap(8),
          Text('Sign a PDF — it will appear here',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SignedPdfCard extends StatelessWidget {
  final SignedPdfEntry entry;
  final VoidCallback onDelete;

  const _SignedPdfCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final exists = File(entry.signedPath).existsSync();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: exists
                ? _neonGreen.withValues(alpha: 0.2)
                : _neonPink.withValues(alpha: 0.2),
            width: 1),
        boxShadow: [
          BoxShadow(
              color: (exists ? _neonGreen : _neonPink).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: exists
                  ? _neonGreen.withValues(alpha: 0.1)
                  : _neonPink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: exists
                      ? _neonGreen.withValues(alpha: 0.3)
                      : _neonPink.withValues(alpha: 0.3)),
            ),
            child: Icon(
                exists ? Icons.picture_as_pdf : Icons.broken_image_outlined,
                color: exists ? _neonGreen : _neonPink,
                size: 26),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fileName,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const Gap(3),
                Text(
                  _formatDate(entry.signedAt),
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 11),
                ),
                if (!exists)
                  Text('File moved or deleted',
                      style: GoogleFonts.inter(
                          color: _neonPink.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          // Actions
          if (exists)
            GestureDetector(
              onTap: () {
                // Open the signed PDF
                Navigator.pop(context);
                // Navigate using the existing OpenPdf approach
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Opening: ${entry.fileName}',
                      style: GoogleFonts.inter()),
                  backgroundColor: const Color(0xFF1E293B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _neonGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _neonGreen.withValues(alpha: 0.3), width: 1),
                ),
                child: const Icon(Icons.open_in_new,
                    color: _neonGreen, size: 18),
              ),
            ),
          const Gap(8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _neonPink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _neonPink.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(Icons.delete_outline,
                  color: _neonPink, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) {
      return '${dt.day}/${dt.month}/${dt.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    return 'Just now';
  }
}
