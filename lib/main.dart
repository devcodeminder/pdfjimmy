import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfjimmy/screens/home_screen.dart';
import 'package:pdfjimmy/screens/splash_screen.dart';
import 'package:pdfjimmy/services/dictionary.dart';
import 'package:pdfjimmy/services/pdf_service.dart';

import 'package:pdfjimmy/controllers/pdf_controller.dart';
import 'package:pdfjimmy/providers/signature_provider.dart';

import 'package:provider/provider.dart';
import 'package:pdfjimmy/services/password_storage_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for Desktop (Windows, Linux, MacOS)
  // Initialize sqflite for Desktop (Windows, Linux, MacOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await GetStorage.init();

  await PasswordStorageService.instance.init();

  Get.lazyPut(() => DictionaryController());
  if (!kIsWeb) {
    await PdfService.instance.initDatabase();
  }
  Get.lazyPut(() => PdfService.instance);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🎨 Premium Color Palette - Sophisticated & Professional
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PdfController()),
        ChangeNotifierProvider(create: (_) => SignatureProvider()..init()),
      ],
      child: Consumer<PdfController>(
        builder: (context, controller, child) {
          return GetMaterialApp(
            title: 'PDFJimmy',
            debugShowCheckedModeBanner: false,
            // Integrate App Lock Wrapper
            themeMode: controller.isNightMode
                ? ThemeMode.dark
                : ThemeMode.light,

            // ☀️ LIGHT THEME - Premium Game Style (Matches Screenshot Style)
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
              primaryColor: const Color(0xFFFF5722), // Deep Orange

              textTheme:
                  GoogleFonts.outfitTextTheme(
                    ThemeData.light().textTheme,
                  ).copyWith(
                    headlineMedium: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: const Color(0xFF1E293B),
                    ),
                    titleLarge: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: const Color(0xFF1E293B),
                    ),
                  ),

              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFF5722),
                brightness: Brightness.light,
                background: const Color(0xFFF8FAFC),
                surface: Colors.white,
                primary: const Color(0xFFFF5722),
                secondary: const Color(0xFFFF8A65),
              ),

              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                titleTextStyle: GoogleFonts.outfit(
                  color: const Color(0xFF1E293B),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),

              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 8, // Higher elevation for pop
                shadowColor: const Color(0xFFFF5722).withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: const Color(0xFFFF5722).withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0xFFFF5722).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF5722),
                    width: 2.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
              ),

              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: ZoomPageTransitionsBuilder(),
                },
              ),
            ),

            // 🌑 DARK THEME - Premium Game Style (The Main Look)
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(
                0xFF0F1115,
              ), // Deep Black/Blue background
              primaryColor: const Color(0xFFFF5722),

              textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
                  .copyWith(
                    headlineMedium: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                    titleLarge: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                    bodyMedium: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8), // Slate 400 text
                    ),
                  ),

              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFF5722), // Deep Orange
                brightness: Brightness.dark,
                background: const Color(0xFF0F1115),
                surface: const Color(0xFF1A1F2E), // Card Color
                primary: const Color(0xFFFF5722),
                secondary: const Color(0xFFFF8A65),
              ),

              appBarTheme: AppBarTheme(
                backgroundColor: const Color(0xFF0F1115).withOpacity(0.9),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              cardTheme: CardThemeData(
                color: const Color(0xFF1A1F2E), // Dark Navy Card
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0xFFFF5722).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF1A1F2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF5722),
                    width: 2.5,
                  ),
                ),
              ),

              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            home: const SplashScreen(),
            getPages: [GetPage(name: '/home', page: () => const HomeScreen())],
          );
        },
      ),
    );
  }
}
