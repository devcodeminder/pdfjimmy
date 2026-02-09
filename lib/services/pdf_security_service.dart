import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service to handle PDF security operations (Encrypt, Decrypt, Change Password)
class PdfSecurityService {
  static final PdfSecurityService instance = PdfSecurityService._init();

  PdfSecurityService._init();

  /// Encrypt a PDF with a password and save to a new location
  Future<String> encryptPdf({
    required String inputPath,
    required String outputPath,
    required String userPassword,
    String? ownerPassword,
    List<PdfPermissionsFlags>? permissions,
  }) async {
    try {
      // Load the document
      final File file = File(inputPath);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Set security settings
      final PdfSecurity security = document.security;
      security.algorithm = PdfEncryptionAlgorithm.aesx256BitRevision6;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword ?? userPassword;

      // Set permissions if provided
      if (permissions != null) {
        security.permissions.clear();
        security.permissions.addAll(permissions);
      }

      // Save to new path
      final File outputFile = File(outputPath);
      final List<int> encryptedBytes = await document.save();
      await outputFile.writeAsBytes(encryptedBytes);

      document.dispose();
      return outputPath;
    } catch (e) {
      print('Error encrypting PDF: $e');
      rethrow;
    }
  }

  /// Remove password from a PDF (Decrypt) and save to a new location
  Future<String> removePassword({
    required String inputPath,
    required String outputPath,
    required String currentPassword,
  }) async {
    try {
      // Load the encrypted document
      final File file = File(inputPath);
      final List<int> bytes = await file.readAsBytes();

      // Load with password
      final PdfDocument document = PdfDocument(
        inputBytes: bytes,
        password: currentPassword,
      );

      // Remove security
      // To remove security in Syncfusion, we can create a new document
      // and import pages, or simpler: clear security settings if supported.
      // Easiest reliable way: Import pages to a new clean document

      final PdfDocument newDocument = PdfDocument();

      // Copy all pages
      for (int i = 0; i < document.pages.count; i++) {
        // Use createTemplate to maintain fidelity
        final PdfTemplate template = document.pages[i].createTemplate();
        newDocument.pages.add().graphics.drawPdfTemplate(
          template,
          Offset(0, 0),
        );
      }

      // Copy metadata if needed
      newDocument.documentInformation.title =
          document.documentInformation.title;
      newDocument.documentInformation.author =
          document.documentInformation.author;
      newDocument.documentInformation.subject =
          document.documentInformation.subject;

      // Save unlocked file
      final File outputFile = File(outputPath);
      final List<int> decryptedBytes = await newDocument.save();
      await outputFile.writeAsBytes(decryptedBytes);

      document.dispose();
      newDocument.dispose();

      return outputPath;
    } catch (e) {
      print('Error removing password: $e');
      rethrow;
    }
  }

  /// Change the password of a PDF and save to a new location
  Future<String> changePassword({
    required String inputPath,
    required String outputPath,
    required String currentPassword,
    required String newPassword,
    String? newOwnerPassword,
  }) async {
    try {
      // Load the encrypted document
      final File file = File(inputPath);
      final List<int> bytes = await file.readAsBytes();

      // Load with current password
      final PdfDocument document = PdfDocument(
        inputBytes: bytes,
        password: currentPassword,
      );

      // Create a new document to apply new security settings cleanly
      // (similar to remove password, but then adding new security)
      // This avoids compatibility issues with simply re-saving the old doc
      final PdfDocument newDocument = PdfDocument();

      for (int i = 0; i < document.pages.count; i++) {
        final PdfTemplate template = document.pages[i].createTemplate();
        newDocument.pages.add().graphics.drawPdfTemplate(
          template,
          Offset(0, 0),
        );
      }

      // Apply new security settings
      final PdfSecurity security = newDocument.security;
      security.algorithm = PdfEncryptionAlgorithm.aesx256BitRevision6;
      security.userPassword = newPassword;
      security.ownerPassword = newOwnerPassword ?? newPassword;

      // Save to new path
      final File outputFile = File(outputPath);
      final List<int> reencryptedBytes = await newDocument.save();
      await outputFile.writeAsBytes(reencryptedBytes);

      document.dispose();
      newDocument.dispose();

      return outputPath;
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }

  /// Check if a PDF is password protected
  Future<bool> isPasswordProtected(String filePath) async {
    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();

      // Attempt to load without password.
      // Syncfusion typically throws if password is required but not provided.
      try {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        document.dispose();
        return false;
      } catch (e) {
        // If it fails, assume it's protected (or corrupted, but predominantly protected if valid PDF)
        // Ideally checking specific error message would be better, but generic catch is safe for boolean check
        return true;
      }
    } catch (e) {
      print('Error checking protections: $e');
      return false; // File probably doesn't exist or IO error
    }
  }
}
