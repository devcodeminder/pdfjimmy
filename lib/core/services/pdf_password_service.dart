import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service to handle PDF password protection and encryption
class PdfPasswordService {
  static final PdfPasswordService instance = PdfPasswordService._init();

  PdfPasswordService._init();

  /// Check if a PDF is password protected
  Future<bool> isPdfPasswordProtected(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final bytes = await file.readAsBytes();

      // Try to load the PDF without password
      try {
        final document = PdfDocument(inputBytes: bytes);
        document.dispose();
        return false; // PDF is not password protected
      } catch (e) {
        // If loading fails, it might be password protected
        if (e.toString().contains('password') ||
            e.toString().contains('encrypted') ||
            e.toString().contains('Invalid cross reference table')) {
          return true;
        }
        rethrow;
      }
    } catch (e) {
      // Log error silently in production
      debugPrint('Error checking PDF password protection: $e');
      return false;
    }
  }

  /// Open a password-protected PDF with the given password
  Future<PdfDocument?> openPasswordProtectedPdf(
    String filePath,
    String password,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final bytes = await file.readAsBytes();

      // Try to load the PDF with password
      final document = PdfDocument(inputBytes: bytes, password: password);

      return document;
    } catch (e) {
      debugPrint('Error opening password-protected PDF: $e');
      return null;
    }
  }

  /// Verify if the password is correct for a PDF
  Future<bool> verifyPassword(String filePath, String password) async {
    try {
      final document = await openPasswordProtectedPdf(filePath, password);
      if (document != null) {
        document.dispose();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying password: $e');
      return false;
    }
  }

  /// Add password protection to a PDF
  Future<String?> addPasswordProtection({
    required String sourcePath,
    required String userPassword,
    String? ownerPassword,
    List<PdfPermissionsFlags>? permissionsList,
  }) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        throw Exception('Source file does not exist');
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Set up security
      final security = document.security;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword ?? userPassword;

      // Set encryption algorithm (use AES 256-bit)
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      // Set permissions using the permissions property
      if (permissionsList != null && permissionsList.isNotEmpty) {
        // Add each permission flag
        for (final flag in permissionsList) {
          security.permissions.add(flag);
        }
      } else {
        // Default permissions
        security.permissions.addAll([
          PdfPermissionsFlags.print,
          PdfPermissionsFlags.copyContent,
          PdfPermissionsFlags.editAnnotations,
          PdfPermissionsFlags.fillFields,
        ]);
      }

      // Save the protected PDF
      final List<int> protectedBytes = await document.save();
      document.dispose();

      // Create output path
      final directory = await getApplicationDocumentsDirectory();
      final fileName = sourcePath
          .split(Platform.pathSeparator)
          .last
          .replaceAll('.pdf', '_protected.pdf');
      final outputPath = '${directory.path}${Platform.pathSeparator}$fileName';

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(protectedBytes);

      return outputPath;
    } catch (e) {
      debugPrint('Error adding password protection: $e');
      return null;
    }
  }

  /// Remove password protection from a PDF
  Future<String?> removePasswordProtection({
    required String sourcePath,
    required String password,
  }) async {
    try {
      final document = await openPasswordProtectedPdf(sourcePath, password);
      if (document == null) {
        throw Exception('Invalid password or unable to open PDF');
      }

      // Save without password protection
      final List<int> unprotectedBytes = await document.save();
      document.dispose();

      // Create output path
      final directory = await getApplicationDocumentsDirectory();
      final fileName = sourcePath
          .split(Platform.pathSeparator)
          .last
          .replaceAll('_protected.pdf', '_unprotected.pdf');
      final outputPath = '${directory.path}${Platform.pathSeparator}$fileName';

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(unprotectedBytes);

      return outputPath;
    } catch (e) {
      debugPrint('Error removing password protection: $e');
      return null;
    }
  }

  /// Change password of a password-protected PDF
  Future<String?> changePassword({
    required String sourcePath,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      // First, open with old password
      final document = await openPasswordProtectedPdf(sourcePath, oldPassword);
      if (document == null) {
        throw Exception('Invalid old password');
      }

      // Set new password
      final security = document.security;
      security.userPassword = newPassword;
      security.ownerPassword = newPassword;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      // Save with new password
      final List<int> newBytes = await document.save();
      document.dispose();

      // Create output path
      final directory = await getApplicationDocumentsDirectory();
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final outputPath = '${directory.path}${Platform.pathSeparator}$fileName';

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(newBytes);

      return outputPath;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return null;
    }
  }

  /// Protect PDF with custom filename and save to ProtectedPDFs folder
  /// Creates a dedicated folder in internal storage for protected PDFs
  Future<String?> protectPdfWithCustomName({
    required String sourcePath,
    required String newPassword,
    String? currentPassword,
    required String customFileName,
    String? outputDirectory,
    List<PdfPermissionsFlags>? permissionsList,
  }) async {
    try {
      PdfDocument? document;

      // If PDF is already protected, open with current password
      if (currentPassword != null && currentPassword.isNotEmpty) {
        document = await openPasswordProtectedPdf(sourcePath, currentPassword);
        if (document == null) {
          throw Exception('Invalid current password');
        }
      } else {
        // Open unprotected PDF
        final file = File(sourcePath);
        if (!await file.exists()) {
          throw Exception('Source file does not exist');
        }
        final bytes = await file.readAsBytes();
        document = PdfDocument(inputBytes: bytes);
      }

      // Set up security with new password
      final security = document.security;
      security.userPassword = newPassword;
      security.ownerPassword = newPassword;

      // Set encryption algorithm (use AES 256-bit)
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      // Set permissions
      if (permissionsList != null && permissionsList.isNotEmpty) {
        for (final flag in permissionsList) {
          security.permissions.add(flag);
        }
      } else {
        // Default permissions
        security.permissions.addAll([
          PdfPermissionsFlags.print,
          PdfPermissionsFlags.copyContent,
          PdfPermissionsFlags.editAnnotations,
          PdfPermissionsFlags.fillFields,
        ]);
      }

      // Save the protected PDF
      final List<int> protectedBytes = await document.save();
      document.dispose();

      // Determine output directory - Prioritize External Storage for visibility
      // Determine output directory
      Directory saveDir;

      if (outputDirectory != null) {
        // User selected specific directory - Save directly here (No subfolder)
        saveDir = Directory(outputDirectory);
      } else {
        // Default Location: Use a "ProtectedPDFs" subfolder in App Documents/External
        Directory? baseDir;
        if (Platform.isAndroid) {
          baseDir = await getExternalStorageDirectory();
        }
        baseDir ??= await getApplicationDocumentsDirectory();

        saveDir = Directory(
          '${baseDir.path}${Platform.pathSeparator}ProtectedPDFs',
        );
      }

      // Ensure directory exists
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // Ensure filename has .pdf extension
      String fileName = customFileName.trim();
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }

      // Create output path
      final outputPath = '${saveDir.path}${Platform.pathSeparator}$fileName';

      // Save the file
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(protectedBytes);

      debugPrint('Protected PDF saved to: $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('Error protecting PDF with custom name: $e');
      return null;
    }
  }

  /// Get the ProtectedPDFs folder path
  Future<String> getProtectedPdfsFolderPath() async {
    Directory documentsDir;
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      documentsDir = externalDir ?? await getApplicationDocumentsDirectory();
    } else {
      documentsDir = await getApplicationDocumentsDirectory();
    }

    final protectedPdfsDir = Directory(
      '${documentsDir.path}${Platform.pathSeparator}ProtectedPDFs',
    );

    // Create directory if it doesn't exist
    if (!await protectedPdfsDir.exists()) {
      await protectedPdfsDir.create(recursive: true);
    }

    return protectedPdfsDir.path;
  }

  /// Get PDF information without opening it
  Future<Map<String, dynamic>> getPdfInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final bytes = await file.readAsBytes();
      final isProtected = await isPdfPasswordProtected(filePath);

      return {
        'filePath': filePath,
        'fileName': filePath.split(Platform.pathSeparator).last,
        'fileSize': bytes.length,
        'isPasswordProtected': isProtected,
      };
    } catch (e) {
      debugPrint('Error getting PDF info: $e');
      return {};
    }
  }

  /// Hash password for secure storage
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a temporary unprotected copy for viewing
  Future<String?> createTempUnprotectedCopy({
    required String sourcePath,
    required String password,
  }) async {
    try {
      final document = await openPasswordProtectedPdf(sourcePath, password);
      if (document == null) {
        throw Exception('Invalid password');
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = sourcePath
          .split(Platform.pathSeparator)
          .last
          .replaceAll('.pdf', '_temp.pdf');
      final tempPath = '${tempDir.path}${Platform.pathSeparator}$fileName';

      final List<int> bytes = await document.save();
      document.dispose();

      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);

      return tempPath;
    } catch (e) {
      debugPrint('Error creating temp copy: $e');
      return null;
    }
  }

  /// Clean up temporary files
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (var file in files) {
        if (file.path.endsWith('_temp.pdf')) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }

  /// Get PDF permissions
  Future<PdfPermissions?> getPdfPermissions(
    String filePath,
    String? password,
  ) async {
    try {
      PdfDocument? document;

      if (password != null && password.isNotEmpty) {
        document = await openPasswordProtectedPdf(filePath, password);
      } else {
        final bytes = await File(filePath).readAsBytes();
        document = PdfDocument(inputBytes: bytes);
      }

      if (document == null) {
        return null;
      }

      final permissions = document.security.permissions;
      document.dispose();

      return permissions;
    } catch (e) {
      debugPrint('Error getting PDF permissions: $e');
      return null;
    }
  }

  /// Check if a specific permission is granted
  /// Note: Due to Syncfusion API limitations, this returns true if PDF has any permissions set
  Future<bool> hasPermission(
    String filePath,
    PdfPermissionsFlags permission,
    String? password,
  ) async {
    try {
      final permissions = await getPdfPermissions(filePath, password);
      // If we can get permissions object, assume permission exists
      // The Syncfusion PdfPermissions class doesn't expose individual permission checks
      return permissions != null;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }
}

// Add debugPrint function for production-safe logging
void debugPrint(String message) {
  // In production, this could be replaced with proper logging
  // For now, we'll use print but it's wrapped for easy replacement
  // ignore: avoid_print
  print(message);
}
