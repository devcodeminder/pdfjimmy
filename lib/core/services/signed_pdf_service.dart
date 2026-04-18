import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A single entry representing a locally-saved signed PDF.
class SignedPdfEntry {
  final String id;
  final String originalPath;
  final String signedPath;
  final String fileName;
  final DateTime signedAt;

  SignedPdfEntry({
    required this.id,
    required this.originalPath,
    required this.signedPath,
    required this.fileName,
    required this.signedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalPath': originalPath,
        'signedPath': signedPath,
        'fileName': fileName,
        'signedAt': signedAt.millisecondsSinceEpoch,
      };

  factory SignedPdfEntry.fromJson(Map<String, dynamic> j) => SignedPdfEntry(
        id: j['id'] as String,
        originalPath: j['originalPath'] as String,
        signedPath: j['signedPath'] as String,
        fileName: j['fileName'] as String,
        signedAt:
            DateTime.fromMillisecondsSinceEpoch(j['signedAt'] as int),
      );
}

/// Persistence layer for signed PDFs (JSON file in app documents).
class SignedPdfService {
  SignedPdfService._();
  static final SignedPdfService instance = SignedPdfService._();

  static const _fileName = 'signed_pdfs.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<SignedPdfEntry>> getAll() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return [];
      final raw = await f.readAsString();
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => SignedPdfEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.signedAt.compareTo(a.signedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> addSignedPdf({
    required String originalPath,
    required String signedPath,
    required String fileName,
  }) async {
    final entries = await getAll();
    entries.insert(
      0,
      SignedPdfEntry(
        id: const Uuid().v4(),
        originalPath: originalPath,
        signedPath: signedPath,
        fileName: fileName,
        signedAt: DateTime.now(),
      ),
    );
    await _persist(entries);
  }

  Future<void> removeEntry(String id) async {
    final entries = await getAll();
    entries.removeWhere((e) => e.id == id);
    await _persist(entries);
  }

  Future<void> _persist(List<SignedPdfEntry> entries) async {
    final f = await _file();
    await f.writeAsString(json.encode(entries.map((e) => e.toJson()).toList()));
  }
}
