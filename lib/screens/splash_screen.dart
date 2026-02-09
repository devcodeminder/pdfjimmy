import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:pdfjimmy/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isNavigated = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    // Initialize the video controller with the asset
    _controller = VideoPlayerController.asset('assets/splash.mp4');

    try {
      await _controller.initialize();

      if (mounted) {
        setState(() {
          _initialized = true;
        });

        // Start playing
        await _controller.play();

        // Navigate after 4 seconds exactly
        Future.delayed(const Duration(seconds: 4), _navigateToHome);
      }
    } catch (e) {
      debugPrint('Error initializing splash video: $e');
      // If video fails, fallback to navigation
      if (mounted) {
        Future.delayed(const Duration(seconds: 4), _navigateToHome);
      }
    }
  }

  void _navigateToHome() {
    if (_isNavigated) return;
    _isNavigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _initialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain, // Maintain aspect ratio, show full content
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const SizedBox(),
    );
  }
}
