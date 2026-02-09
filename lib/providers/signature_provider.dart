import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/signature_data.dart';

class SignatureProvider extends ChangeNotifier {
  final List<SignatureData> _signatures = [];
  bool _isLoading = false;

  List<SignatureData> get signatures => _signatures;
  bool get isLoading => _isLoading;

  // Get favorites
  List<SignatureData> get favoriteSignatures =>
      _signatures.where((s) => s.isFavorite).toList();

  // Get by type
  List<SignatureData> getSignaturesByType(SignatureType type) =>
      _signatures.where((s) => s.type == type).toList();

  Future<void> init() async {
    await loadStoredSignatures();
  }

  // Create hand-drawn signature
  Future<void> createDrawnSignature({
    required String name,
    required Uint8List imageData,
    required Color strokeColor,
    required double strokeWidth,
  }) async {
    final signature = SignatureData(
      id: const Uuid().v4(),
      name: name,
      imageData: imageData,
      createdAt: DateTime.now(),
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      type: SignatureType.drawn,
    );

    _signatures.add(signature);
    await _saveSignatures();
    notifyListeners();
  }

  // Create signature from image
  Future<void> createImageSignature({
    required String name,
    required Uint8List imageData,
  }) async {
    final signature = SignatureData(
      id: const Uuid().v4(),
      name: name,
      imageData: imageData,
      createdAt: DateTime.now(),
      type: SignatureType.image,
    );

    _signatures.add(signature);
    await _saveSignatures();
    notifyListeners();
  }

  // Create signature from template
  Future<void> createTemplateSignature({
    required String name,
    required Uint8List imageData,
    required String templateId,
    Color? strokeColor,
  }) async {
    final signature = SignatureData(
      id: const Uuid().v4(),
      name: name,
      imageData: imageData,
      createdAt: DateTime.now(),
      type: SignatureType.template,
      templateId: templateId,
      strokeColor: strokeColor ?? Colors.black,
    );

    _signatures.add(signature);
    await _saveSignatures();
    notifyListeners();
  }

  // Import signature from camera/gallery
  Future<void> importSignature(ImageSource source) async {
    try {
      _isLoading = true;
      notifyListeners();

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        final imageData = await File(pickedFile.path).readAsBytes();
        final name = 'Signature ${_signatures.length + 1}';

        await createImageSignature(name: name, imageData: imageData);
      }
    } catch (e) {
      print('Error importing signature: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Toggle favorite
  void toggleFavorite(String signatureId) {
    final index = _signatures.indexWhere((s) => s.id == signatureId);
    if (index != -1) {
      _signatures[index] = _signatures[index].copyWith(
        isFavorite: !_signatures[index].isFavorite,
      );
      _saveSignatures();
      notifyListeners();
    }
  }

  // Increment usage count
  void incrementUsage(String signatureId) {
    final index = _signatures.indexWhere((s) => s.id == signatureId);
    if (index != -1) {
      _signatures[index] = _signatures[index].copyWith(
        usageCount: _signatures[index].usageCount + 1,
      );
      _saveSignatures();
      notifyListeners();
    }
  }

  // Rename signature
  void renameSignature(String signatureId, String newName) {
    final index = _signatures.indexWhere((s) => s.id == signatureId);
    if (index != -1) {
      _signatures[index] = _signatures[index].copyWith(name: newName);
      _saveSignatures();
      notifyListeners();
    }
  }

  // Update signature (for editing)
  void updateSignature(
    String signatureId, {
    Uint8List? imageData,
    double? rotation,
  }) {
    final index = _signatures.indexWhere((s) => s.id == signatureId);
    if (index != -1) {
      _signatures[index] = _signatures[index].copyWith(
        imageData: imageData,
        rotation: rotation,
      );
      _saveSignatures();
      notifyListeners();
    }
  }

  // Delete signature
  void deleteSignature(String signatureId) {
    _signatures.removeWhere((s) => s.id == signatureId);
    _saveSignatures();
    notifyListeners();
  }

  // Duplicate signature
  Future<void> duplicateSignature(String signatureId) async {
    final original = _signatures.firstWhere((s) => s.id == signatureId);
    final duplicate = SignatureData(
      id: const Uuid().v4(),
      name: '${original.name} (Copy)',
      imageData: original.imageData,
      createdAt: DateTime.now(),
      strokeColor: original.strokeColor,
      strokeWidth: original.strokeWidth,
      type: original.type,
      templateId: original.templateId,
      rotation: original.rotation,
    );

    _signatures.add(duplicate);
    await _saveSignatures();
    notifyListeners();
  }

  // Rotate signature
  void rotateSignature(String signatureId, double degrees) {
    final index = _signatures.indexWhere((s) => s.id == signatureId);
    if (index != -1) {
      final currentRotation = _signatures[index].rotation;
      final newRotation = (currentRotation + degrees) % 360;
      _signatures[index] = _signatures[index].copyWith(rotation: newRotation);
      _saveSignatures();
      notifyListeners();
    }
  }

  // Search signatures
  List<SignatureData> searchSignatures(String query) {
    if (query.isEmpty) return _signatures;
    return _signatures
        .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Sort signatures
  List<SignatureData> sortSignatures(String sortBy) {
    final sorted = List<SignatureData>.from(_signatures);
    switch (sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'usage':
        sorted.sort((a, b) => b.usageCount.compareTo(a.usageCount));
        break;
    }
    return sorted;
  }

  // Save signatures to storage
  Future<void> _saveSignatures() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/signatures.json');

      final signaturesJson = _signatures.map((s) => s.toJson()).toList();
      await file.writeAsString(json.encode(signaturesJson));
    } catch (e) {
      print('Error saving signatures: $e');
    }
  }

  // Load stored signatures
  Future<void> loadStoredSignatures() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/signatures.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);

        _signatures.clear();
        _signatures.addAll(
          jsonList.map((json) => SignatureData.fromJson(json)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error loading signatures: $e');
    }
  }

  // Clear all signatures
  Future<void> clearAll() async {
    _signatures.clear();
    await _saveSignatures();
    notifyListeners();
  }
}
