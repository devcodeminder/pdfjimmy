import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'package:pdfjimmy/scanner/crop/post_scan_crop_screen.dart';

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _isFlashOn = false;
  int _currentCameraIndex = 0;
  bool _isAutoCapture = false;
  Timer? _autoCaptureTimer;
  int _secondsRemaining = 3;
  bool _isTimerRunning = false;

  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Force portrait mode for scanning
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _initCamera();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _setupCameraController(_cameras![_currentCameraIndex]);
      } else {
        Get.snackbar('Error', 'No cameras available');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to initialize camera: $e');
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;

      await _cameraController!.setFlashMode(FlashMode.off);
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to setup camera: $e');
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    HapticFeedback.lightImpact();
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _setupCameraController(_cameras![_currentCameraIndex]);
  }

  void _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });

    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _captureImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final XFile image = await _cameraController!.takePicture();

      // Navigate to Crop Screen
      if (mounted) {
        Get.to(
          () => PostScanCropScreen(imagePath: image.path, isFromCamera: true),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to capture image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      Get.to(
        () => PostScanCropScreen(imagePath: image.path, isFromCamera: true),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animationController.dispose();
    // Reset orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _autoCaptureTimer?.cancel();
    super.dispose();
  }

  void _startAutoCaptureTimer() {
    _autoCaptureTimer?.cancel();
    if (!_isAutoCapture || _isCapturing) return;

    setState(() {
      _secondsRemaining = 3;
      _isTimerRunning = true;
    });

    _autoCaptureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isAutoCapture || _isCapturing) {
        timer.cancel();
        setState(() => _isTimerRunning = false);
        return;
      }

      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _isTimerRunning = false;
          timer.cancel();
          _captureImage();
        }
      });
    });
  }

  void _stopAutoCaptureTimer() {
    _autoCaptureTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview
          Positioned.fill(child: CameraPreview(_cameraController!)),

          // 2. Cyberpunk Edge Overlay & Mask
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: CyberpunkScannerOverlayPainter(
                    animationValue: _animationController.value,
                  ),
                );
              },
            ),
          ),

          // 2b. Auto Capture Countdown Overlay
          if (_isTimerRunning)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00F5FF), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F5FF).withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Text(
                  '$_secondsRemaining',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

          // 3. Top Action Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCyberButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                  color: const Color(0xFFFF3CAC),
                ),
                _buildCyberButton(
                  icon: _isFlashOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  onTap: _toggleFlash,
                  color: _isFlashOn ? const Color(0xFFFFD700) : Colors.white,
                ),
              ],
            ),
          ),

          // 4. Bottom Control Bar (Game Look)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                top: 32,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF060610).withOpacity(0.95),
                    const Color(0xFF060610).withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode Selection (Manual vs Auto)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton('Manual', !_isAutoCapture),
                        _buildModeButton('Auto capture', _isAutoCapture),
                      ],
                    ),
                  ),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery button
                      _buildGalleryButton(),

                      // Shutter button
                      _buildShutterButton(),

                      // Switch camera
                      _buildSwitchCameraButton(),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'pdfjimmy will have access only to the images that you scan',
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white54,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1E),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildModeButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          HapticFeedback.selectionClick();
          setState(() {
            _isAutoCapture = text.toLowerCase().contains('auto');
            if (_isAutoCapture) {
              _startAutoCaptureTimer();
            } else {
              _stopAutoCaptureTimer();
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9B59FF).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFF9B59FF), width: 1.5)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF9B59FF).withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.rajdhani(
            color: isSelected ? const Color(0xFF00F5FF) : Colors.white54,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return GestureDetector(
      onTap: _pickFromGallery,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF3CAC).withOpacity(0.2),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFFF3CAC).withOpacity(0.7),
            width: 1.5,
          ),
          color: const Color(0xFF0D0D1E),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3CAC).withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.photo_library_outlined,
          color: Color(0xFFFF3CAC),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSwitchCameraButton() {
    return GestureDetector(
      onTap: _switchCamera,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00F5FF).withOpacity(0.2),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF00F5FF).withOpacity(0.7),
            width: 1.5,
          ),
          color: const Color(0xFF0D0D1E),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F5FF).withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.flip_camera_ios_outlined,
          color: Color(0xFF00F5FF),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _captureImage,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B59FF), Color(0xFFFF3CAC)],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3CAC).withOpacity(0.6),
                  blurRadius: _glowAnimation.value * 2,
                  spreadRadius: _glowAnimation.value / 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white54, width: 2),
                ),
                child: const Icon(Icons.camera, color: Colors.white, size: 30),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CyberpunkScannerOverlayPainter extends CustomPainter {
  final double animationValue;

  CyberpunkScannerOverlayPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Define Frame Proportions (Centered)
    final frameWidth = size.width * 0.85;
    final frameHeight = size.height * 0.55;

    final centerX = size.width / 2;
    final centerY =
        size.height * 0.45; // Slightly above center for better ergonomics

    final left = centerX - frameWidth / 2;
    final top = centerY - frameHeight / 2;
    final right = centerX + frameWidth / 2;
    final bottom = centerY + frameHeight / 2;
    final rect = Rect.fromLTRB(left, top, right, bottom);

    // 2. Draw Background Mask (Dimmed area outside frame)
    final maskPaint = Paint()..color = Colors.black.withOpacity(0.65);
    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    final combinedPath = Path.combine(
      PathOperation.difference,
      outerPath,
      innerPath,
    );
    canvas.drawPath(combinedPath, maskPaint);

    // 3. Draw Heavy Corner Brackets (More visible)
    final cornerPaint = Paint()
      ..color = const Color(0xFF00F5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.square;

    final cornerSize = 40.0;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerSize)
        ..lineTo(left, top)
        ..lineTo(left + cornerSize, top),
      cornerPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerSize, top)
        ..lineTo(right, top)
        ..lineTo(right, top + cornerSize),
      cornerPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cornerSize)
        ..lineTo(left, bottom)
        ..lineTo(left + cornerSize, bottom),
      cornerPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerSize, bottom)
        ..lineTo(right, bottom)
        ..lineTo(right, bottom - cornerSize),
      cornerPaint,
    );

    // 4. Draw Center Crosshair
    final centerPaint = Paint()
      ..color = const Color(0xFFFF3CAC).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const crossSize = 15.0;
    canvas.drawLine(
      Offset(centerX - crossSize, centerY),
      Offset(centerX + crossSize, centerY),
      centerPaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - crossSize),
      Offset(centerX, centerY + crossSize),
      centerPaint,
    );

    // 5. Draw Target Dots in corners
    final dotPaint = Paint()..color = const Color(0xFF00F5FF).withOpacity(0.5);
    canvas.drawCircle(Offset(left + 10, top + 10), 2, dotPaint);
    canvas.drawCircle(Offset(right - 10, top + 10), 2, dotPaint);
    canvas.drawCircle(Offset(left + 10, bottom - 10), 2, dotPaint);
    canvas.drawCircle(Offset(right - 10, bottom - 10), 2, dotPaint);

    // 6. Draw Animated Scan Line
    final scanLinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF00F5FF).withOpacity(0.0),
          const Color(0xFF00F5FF).withOpacity(1.0),
          const Color(0xFF00F5FF).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(left, 0, frameWidth, 2))
      ..strokeWidth = 2.5;

    // Ping-pong relative to frame
    final scanY =
        top +
        (frameHeight * (0.5 + 0.5 * math.sin(animationValue * 2 * math.pi)));

    canvas.drawLine(
      Offset(left + 2, scanY),
      Offset(right - 2, scanY),
      scanLinePaint,
    );

    // Glow Trail
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00F5FF).withOpacity(0.2),
          const Color(0xFF00F5FF).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(left, scanY, frameWidth, 50));

    if (math.cos(animationValue * 2 * math.pi) > 0) {
      canvas.drawRect(
        Rect.fromLTWH(left + 2, scanY, frameWidth - 4, 40),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CyberpunkScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
