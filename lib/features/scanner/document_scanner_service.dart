import 'package:cunning_document_scanner/cunning_document_scanner.dart';

class DocumentScannerService {
  Future<List<String>?> scanDocuments() async {
    try {
      // Trigger the cunning document scanner
      // This will open the camera interface for scanning documents
      List<String>? pictures = await CunningDocumentScanner.getPictures();
      return pictures;
    } catch (e) {
      // Handle any errors during the scanning process
      print("Error scanning documents: $e");
      return null;
    }
  }
}
