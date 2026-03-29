import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR using Google ML Kit.
/// The ML Kit pipeline runs off the main UI thread internally,
/// but we still call it via async/await so the UI stays responsive.
class OcrService {
  OcrService._();
  static final instance = OcrService._();

  /// Extracts raw text from an image file.
  /// Returns the concatenated recognized text, or null on failure.
  Future<String?> recognizeText(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final raw = recognizedText.text.trim();
      return raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    } finally {
      await textRecognizer.close();
    }
  }
}
