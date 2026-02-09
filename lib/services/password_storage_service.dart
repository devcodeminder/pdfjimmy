import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import '../models/saved_pdf_model.dart';

/// Service to securely store and manage PDF passwords
class PasswordStorageService {
  static final PasswordStorageService instance = PasswordStorageService._init();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GetStorage _metaStorage = GetStorage('pdf_passwords_meta');

  // In-memory cache: hashedFilePath -> password
  final Map<String, String> _passwordsCache = {};

  // Metadata cache: hashedFilePath -> SavedPdfModel
  final Map<String, SavedPdfModel> _metadataCache = {};

  bool _initialized = false;
  static const String _passwordPrefix = 'pdf_pass_';
  static const String _rememberPasswordsKey = 'remember_passwords';
  static const String _metadataKey = 'saved_pdfs_metadata';

  bool _rememberPasswords = true;

  PasswordStorageService._init();

  Future<void> init() async {
    if (_initialized) return;

    try {
      final rememberVal = await _secureStorage.read(key: _rememberPasswordsKey);
      _rememberPasswords = rememberVal != 'false';

      if (_rememberPasswords) {
        // Load metadata
        final metaData = _metaStorage.read(_metadataKey);
        if (metaData != null && metaData is Map) {
          metaData.forEach((key, value) {
            _metadataCache[key] = SavedPdfModel.fromJson(value);
          });
        }

        // Load passwords into memory
        final allItems = await _secureStorage.readAll();
        allItems.forEach((key, value) {
          if (key.startsWith(_passwordPrefix)) {
            final hashedPath = key.substring(_passwordPrefix.length);
            _passwordsCache[hashedPath] = value;
          }
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing PasswordStorageService: $e');
      _initialized = true;
    }
  }

  Future<void> savePassword(String filePath, String password) async {
    if (!_rememberPasswords) return;

    try {
      final hashedPath = _hashFilePath(filePath);
      final fileName = filePath
          .split('/')
          .last
          .split('\\')
          .last; // Simple filename extraction

      // 1. Save Password Securely
      _passwordsCache[hashedPath] = password;
      await _secureStorage.write(
        key: '$_passwordPrefix$hashedPath',
        value: password,
      );

      // 2. Save Metadata
      final model = SavedPdfModel(
        path: filePath,
        fileName: fileName,
        dateAdded: DateTime.now(),
      );
      _metadataCache[hashedPath] = model;
      await _saveMetadata();
    } catch (e) {
      debugPrint('Error saving password: $e');
    }
  }

  String? getPassword(String filePath) {
    if (!_initialized) debugPrint('Warning: Service accessed before init');
    final hashedPath = _hashFilePath(filePath);
    return _passwordsCache[hashedPath];
  }

  bool hasPassword(String filePath) {
    final hashedPath = _hashFilePath(filePath);
    return _passwordsCache.containsKey(hashedPath);
  }

  Future<void> removePassword(String filePath) async {
    try {
      final hashedPath = _hashFilePath(filePath);

      _passwordsCache.remove(hashedPath);
      _metadataCache.remove(hashedPath);

      await _secureStorage.delete(key: '$_passwordPrefix$hashedPath');
      await _saveMetadata();
    } catch (e) {
      debugPrint('Error removing password: $e');
    }
  }

  Future<void> clearAllPasswords() async {
    try {
      _passwordsCache.clear();
      _metadataCache.clear();

      final allItems = await _secureStorage.readAll();
      for (var key in allItems.keys) {
        if (key.startsWith(_passwordPrefix)) {
          await _secureStorage.delete(key: key);
        }
      }
      await _metaStorage.remove(_metadataKey);
    } catch (e) {
      debugPrint('Error clearing passwords: $e');
    }
  }

  /// Get list of all saved PDFs with metadata
  List<SavedPdfModel> getSavedPdfs() {
    return _metadataCache.values.toList();
  }

  Future<void> _saveMetadata() async {
    final Map<String, dynamic> jsonMap = {};
    _metadataCache.forEach((key, value) {
      jsonMap[key] = value.toJson();
    });
    await _metaStorage.write(_metadataKey, jsonMap);
  }

  Future<void> updatePassword(String filePath, String newPassword) async {
    await savePassword(filePath, newPassword);
  }

  Map<String, String> exportPasswords() {
    return Map.from(_passwordsCache);
  }

  Future<void> importPasswords(Map<String, String> passwords) async {
    try {
      for (var entry in passwords.entries) {
        final key = entry.key;
        final value = entry.value;
        _passwordsCache[key] = value;
        await _secureStorage.write(key: '$_passwordPrefix$key', value: value);
      }
    } catch (e) {
      debugPrint('Error importing passwords: $e');
    }
  }

  Map<String, dynamic> validatePasswordStrength(String password) {
    final hasMinLength = password.length >= 8;
    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChars = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    int strength = 0;
    if (hasMinLength) strength++;
    if (hasUpperCase) strength++;
    if (hasLowerCase) strength++;
    if (hasDigits) strength++;
    if (hasSpecialChars) strength++;

    return {
      'strength': strength,
      'strengthText': strength <= 2
          ? 'Weak'
          : (strength <= 4 ? 'Medium' : 'Strong'),
      'hasMinLength': hasMinLength,
    };
  }

  String generateStrongPassword({int length = 16}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = DateTime.now().millisecondsSinceEpoch;
    final password = StringBuffer();
    for (int i = 0; i < length; i++) {
      password.write(chars[(random + i) % chars.length]);
    }
    return password.toString();
  }

  Future<void> setRememberPasswords(bool remember) async {
    _rememberPasswords = remember;
    await _secureStorage.write(
      key: _rememberPasswordsKey,
      value: remember.toString(),
    );
    if (!remember) await clearAllPasswords();
  }

  bool shouldRememberPasswords() => _rememberPasswords;

  String _hashFilePath(String filePath) {
    final bytes = utf8.encode(filePath);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
