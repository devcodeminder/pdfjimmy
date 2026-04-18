import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class ScannerService {
  final _documentScanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full,
      pageLimit: 100, // Standard limit for "CamScanner" feel
      isGalleryImport: true,
    ),
  );

  /// Starts the scanning flow (Camera or Gallery based on internal logic of ML Kit).
  /// Returns a list of scanned pages as [Document].
  Future<List<String>> scanDocument() async {
    try {
      final result = await _documentScanner.scanDocument();
      return result.images;
    } catch (e) {
      // Handle "User canceled" or other errors gracefully
      print('Error scanning document: $e');
      return [];
    }
  }

  /// Disposes resources if any
  void dispose() {
    _documentScanner.close();
  }
}
