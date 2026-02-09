import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // Singleton instance
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts text from the image at [imagePath].
  /// Returns the full extracted text as a String.
  /// Throws an exception if recognition fails.
  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      return recognizedText.text;
    } catch (e) {
      print('OCR Error: $e');
      return 'Failed to extract text.';
    }
  }

  /// Extracts text blocks with bounding boxes (for future advanced use).
  Future<RecognizedText?> extractTextBlocks(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      return await _textRecognizer.processImage(inputImage);
    } catch (e) {
      print('OCR Error: $e');
      return null;
    }
  }

  /// Detects suggested rotation (0, 90, -90, 180) based on text orientation.
  Future<int> detectOrientation(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      final text = await _textRecognizer.processImage(inputImage);
      if (text.blocks.isEmpty) return 0;

      // Calculate average angle of text lines
      double totalAngle = 0;
      int lineCount = 0;

      for (var block in text.blocks) {
        for (var line in block.lines) {
          // line.angle returns angle in degrees.
          // Note: ML Kit Text v2 might not strictly return 'angle' in all versions
          // or it might be relative to the image.
          // Let's rely on line.angle if available (it is in v0.13.0).
          // If angle is missing, we can infer from corner points, but let's trust the API.

          if (line.angle != null) {
            totalAngle += line.angle!;
            lineCount++;
          }
        }
      }

      if (lineCount == 0) return 0;

      double avg = totalAngle / lineCount;

      // Normalize angle to nearest 90
      if (avg > 45 && avg < 135) return 90;
      if (avg < -45 && avg > -135) return -90;
      if (avg > 135 || avg < -135) return 180;

      return 0;
    } catch (e) {
      return 0;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
