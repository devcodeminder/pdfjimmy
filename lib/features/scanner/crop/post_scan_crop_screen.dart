import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:pdfjimmy/features/scanner/scanner_controller.dart';
import 'package:pdfjimmy/features/scanner/presentation/scanned_pages_review_screen.dart';
import 'dart:ui' as ui;
import 'quad_crop_widget.dart';

// ─── Gaming Neon Palette ───────────────────────────────────────────────────────
const _bg = Color(0xFF060610);
const _surface = Color(0xFF0D0D1E);
const _neonCyan = Color(0xFF00F5FF);
const _neonPurple = Color(0xFF0280F8);
const _neonPink = Color(0xFFFF3CAC);
const _glass = Color(0x16FFFFFF);
const _glassBorder = Color(0x33FFFFFF);

class PostScanCropScreen extends StatefulWidget {
  final String imagePath;
  final Function(String)? onCropSaved;
  final bool isFromCamera;
  final int? pageIndex;

  const PostScanCropScreen({
    super.key,
    required this.imagePath,
    this.onCropSaved,
    this.isFromCamera = false,
    this.pageIndex,
  });

  @override
  State<PostScanCropScreen> createState() => _PostScanCropScreenState();
}

class _PostScanCropScreenState extends State<PostScanCropScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _imageData;
  ui.Image? _uiImage;
  img.Image? _decodedImage;
  List<Offset> _cropPoints = [];
  bool _loading = true;
  bool _cropping = false;
  bool _isAutoCrop = false;
  Key _cropKey = UniqueKey();

  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: 1800.ms)
      ..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final f = File(widget.imagePath);
    if (await f.exists()) {
      _imageData = await f.readAsBytes();
      _uiImage = await decodeImageFromList(_imageData!);
      _decodedImage = img.decodeImage(_imageData!);
    }
    if (mounted) {
      setState(() => _loading = false);
      // Run auto-crop by default to try and find edges
      _autoCrop();
    }
  }

  Future<void> _autoCrop() async {
    setState(() => _loading = true);
    try {
      if (_imageData != null) {
        final image = img.decodeImage(_imageData!);
        if (image != null) {
          final w = image.width, h = image.height;
          final sx = (w * 0.01).toInt(), sy = (h * 0.01).toInt();
          final ex = w - sx, ey = h - sy;

          int r = 0, g = 0, b = 0, n = 0;
          for (int x = sx; x < ex; x += 10) {
            final p = image.getPixelSafe(x, sy);
            r += p.r.toInt();
            g += p.g.toInt();
            b += p.b.toInt();
            n++;
          }
          if (n > 0) {
            r ~/= n;
            g ~/= n;
            b ~/= n;
          }

          // Advanced 4-Corner Detection
          int tlX = w, tlY = h, tlMin = w + h;
          int trX = 0, trY = h, trMin = w + h;
          int brX = 0, brY = 0, brMin = w + h;
          int blX = w, blY = 0, blMin = w + h;

          bool foundAny = false;

          for (int y = sy; y < ey; y += 15) {
            for (int x = sx; x < ex; x += 15) {
              final p = image.getPixelSafe(x, y);
              final diff =
                  (p.r - r).abs().toInt() +
                  (p.g - g).abs().toInt() +
                  (p.b - b).abs().toInt();

              if (diff > 55) {
                // Sensitivity threshold
                foundAny = true;

                // Score each pixel to "attract" it to the 4 corners
                int tlScore = x + y;
                int trScore = (w - x) + y;
                int brScore = (w - x) + (h - y);
                int blScore = x + (h - y);

                if (tlScore < tlMin) {
                  tlMin = tlScore;
                  tlX = x;
                  tlY = y;
                }
                if (trScore < trMin) {
                  trMin = trScore;
                  trX = x;
                  trY = y;
                }
                if (brScore < brMin) {
                  brMin = brScore;
                  brX = x;
                  brY = y;
                }
                if (blScore < blMin) {
                  blMin = blScore;
                  blX = x;
                  blY = y;
                }
              }
            }
          }

          if (foundAny) {
            _cropPoints = [
              Offset(tlX / w, tlY / h),
              Offset(trX / w, trY / h),
              Offset(brX / w, brY / h),
              Offset(blX / w, blY / h),
            ];
          } else {
            // Fallback to absolute corners if nothing detected
            _cropPoints = [
              const Offset(0.0, 0.0),
              const Offset(1.0, 0.0),
              const Offset(1.0, 1.0),
              const Offset(0.0, 1.0),
            ];
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isAutoCrop = true;
        _loading = false;
        _cropKey = UniqueKey();
      });
    }
  }

  void _toggleAuto() {
    if (_isAutoCrop) {
      setState(() {
        _isAutoCrop = false;
        _cropPoints = [];
        _cropKey = UniqueKey();
      });
    } else {
      _autoCrop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF12103A), _bg],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? _buildLoading()
              : _imageData == null
              ? _buildError()
              : _buildUI(),
        ),
      ),
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _neonPurple.withValues(alpha: 0.08),
                border: Border.all(
                  color: _neonPurple.withValues(alpha: _glow.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _neonPurple.withValues(alpha: 0.3 * _glow.value),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.crop_free_rounded,
                color: _neonPurple,
                size: 36,
              ),
            ),
          ),
          const Gap(18),
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Text(
              _isAutoCrop ? 'DETECTING EDGES...' : 'LOADING IMAGE...',
              style: GoogleFonts.rajdhani(
                color: _neonPurple.withValues(alpha: 0.6 + 0.4 * _glow.value),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: _neonPink, size: 60),
          const Gap(16),
          Text(
            'Failed to load image',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
          ),
          const Gap(24),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_neonPurple, _neonPink],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _neonPurple.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Text(
                'GO BACK',
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main UI ───────────────────────────────────────────────────────────────────
  Widget _buildUI() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(child: _buildCropArea()),
        _buildHint(),
        _buildBottomBar(),
        const Gap(12),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surface, _bg.withValues(alpha: 0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _glass,
                shape: BoxShape.circle,
                border: Border.all(color: _glassBorder, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // Title
          Expanded(
            child: Column(
              children: [
                Text(
                  'CROP & ADJUST',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                AnimatedBuilder(
                  animation: _glow,
                  builder: (_, __) => Text(
                    _isAutoCrop ? '● AUTO CROP ACTIVE' : '● MANUAL MODE',
                    style: GoogleFonts.rajdhani(
                      color: (_isAutoCrop ? _neonCyan : Colors.white30)
                          .withValues(alpha: _isAutoCrop ? _glow.value : 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Auto toggle
          GestureDetector(
            onTap: _toggleAuto,
            child: AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: _isAutoCrop
                    ? const LinearGradient(colors: [_neonCyan, _neonPurple])
                    : null,
                color: _isAutoCrop ? null : _glass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isAutoCrop ? _neonCyan : _glassBorder,
                  width: 1,
                ),
                boxShadow: _isAutoCrop
                    ? [
                        BoxShadow(
                          color: _neonCyan.withValues(alpha: 0.4),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isAutoCrop
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    color: _isAutoCrop ? Colors.black : Colors.white54,
                    size: 14,
                  ),
                  const Gap(6),
                  Text(
                    'AUTO',
                    style: GoogleFonts.rajdhani(
                      color: _isAutoCrop ? Colors.black : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Crop Area ─────────────────────────────────────────────────────────────────
  Widget _buildCropArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Crop widget
            if (_uiImage != null)
              QuadCropWidget(
                key: _cropKey,
                image: _uiImage!,
                initialPoints: _cropPoints,
                onPointsChanged: (pts) => _cropPoints = pts,
              ),
            // Edge glow overlay
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (_, __) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _neonPurple.withValues(alpha: 0.12 * _glow.value),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hint ─────────────────────────────────────────────────────────────────────
  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            color: _neonCyan.withValues(alpha: 0.4),
            size: 14,
          ),
          const Gap(6),
          Text(
            'Drag the corner dots to adjust crop area',
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _neonPurple.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: _neonPurple.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Retake
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (widget.isFromCamera) {
                  final c = Get.find<ScannerController>();
                  if (widget.pageIndex == null && c.scannedPages.isNotEmpty) {
                    c.scannedPages.removeLast();
                  }
                }
                Get.back();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _glass,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _glassBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
                    const Gap(8),
                    Text(
                      'RETAKE',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Gap(14),

          // Continue
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_cropping) return;
                setState(() => _cropping = true);

                if (_decodedImage == null) {
                  setState(() => _cropping = false);
                  return;
                }

                // Small delay to allow UI to show saving state
                await Future.delayed(const Duration(milliseconds: 50));

                try {
                  final pts = _cropPoints.isEmpty
                      ? [
                          const Offset(0.0, 0.0),
                          const Offset(1.0, 0.0),
                          const Offset(1.0, 1.0),
                          const Offset(0.0, 1.0),
                        ]
                      : _cropPoints;

                  final w = _decodedImage!.width;
                  final h = _decodedImage!.height;

                  final cropped = img.copyRectify(
                    _decodedImage!,
                    topLeft: img.Point(pts[0].dx * w, pts[0].dy * h),
                    topRight: img.Point(pts[1].dx * w, pts[1].dy * h),
                    bottomLeft: img.Point(pts[3].dx * w, pts[3].dy * h),
                    bottomRight: img.Point(pts[2].dx * w, pts[2].dy * h),
                  );

                  final jpg = img.encodeJpg(cropped, quality: 90);
                  await _doSave(Uint8List.fromList(jpg));
                } catch (e) {
                  setState(() => _cropping = false);
                  Get.snackbar(
                    'Error',
                    'Failed to crop image.',
                    backgroundColor: _neonPink.withValues(alpha: 0.9),
                    colorText: Colors.white,
                  );
                }
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _cropping
                        ? [
                            _neonPurple.withValues(alpha: 0.5),
                            _neonPink.withValues(alpha: 0.5),
                          ]
                        : [_neonPurple, _neonPink],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _neonPurple.withValues(alpha: _cropping ? 0.2 : 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _cropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                    const Gap(8),
                    Text(
                      _cropping ? 'SAVING...' : 'CONTINUE',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
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

  Future<void> _doSave(Uint8List data) async {
    try {
      final dir = File(widget.imagePath).parent;
      final newPath =
          '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final f = await File(newPath).writeAsBytes(data);

      if (widget.onCropSaved != null) {
        widget.onCropSaved!(f.path);
        Get.back();
      } else if (widget.isFromCamera) {
        final c = Get.find<ScannerController>();
        if (widget.pageIndex != null) {
          c.updatePageWithCrop(widget.pageIndex!, f.path);
        } else {
          c.scannedPages.add(f.path);
        }
        Get.offAll(() => const ScannedPagesReviewScreen());
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Crop save failed: $e',
        backgroundColor: _neonPink.withValues(alpha: 0.9),
        colorText: Colors.white,
        borderRadius: 16,
        margin: const EdgeInsets.all(16),
      );
      if (mounted) setState(() => _cropping = false);
    }
  }
}
