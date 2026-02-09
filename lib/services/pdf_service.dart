import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bookmark_model.dart';
import '../models/pdf_annotation_model.dart';
import '../models/drawing_model.dart';
import '../models/signature_placement_model.dart';

class PdfService {
  static final PdfService instance = PdfService._init();
  static Database? _database;

  PdfService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pdf_reader.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add highlights table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS highlights (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          text TEXT NOT NULL,
          color INTEGER NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');

      // Add underlines table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS underlines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          text TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');

      // Add notes table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add drawings table for freehand drawing feature
      await db.execute('''
        CREATE TABLE IF NOT EXISTS drawings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          pathData TEXT NOT NULL,
          color INTEGER NOT NULL,
          strokeWidth REAL NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      // Add signature_placements table for signature placement feature
      await db.execute('''
        CREATE TABLE IF NOT EXISTS signature_placements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          signatureId TEXT NOT NULL,
          positionX REAL NOT NULL,
          positionY REAL NOT NULL,
          scale REAL NOT NULL,
          rotation REAL NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 5) {
      // Add strikethroughs table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS strikethroughs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          text TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');

      // Add squigglies table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS squigglies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          text TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      // Retrospective fix: Ensure drawings and signature_placements exist
      // because they were missing from _createDB in v5
      await db.execute('''
        CREATE TABLE IF NOT EXISTS drawings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          pathData TEXT NOT NULL,
          color INTEGER NOT NULL,
          strokeWidth REAL NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS signature_placements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          filePath TEXT NOT NULL,
          pageNumber INTEGER NOT NULL,
          signatureId TEXT NOT NULL,
          positionX REAL NOT NULL,
          positionY REAL NOT NULL,
          scale REAL NOT NULL,
          rotation REAL NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        title TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pdf_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL UNIQUE,
        totalPages INTEGER NOT NULL,
        lastPageRead INTEGER DEFAULT 0,
        lastOpened INTEGER NOT NULL,
        fileSize INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        text TEXT NOT NULL,
        color INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE underlines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        text TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE drawings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        pathData TEXT NOT NULL,
        color INTEGER NOT NULL,
        strokeWidth REAL NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE signature_placements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        signatureId TEXT NOT NULL,
        positionX REAL NOT NULL,
        positionY REAL NOT NULL,
        scale REAL NOT NULL,
        rotation REAL NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE strikethroughs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        text TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE squigglies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        text TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> initDatabase() async {
    await database;
  }

  // ✅ BOOKMARKS
  Future<int> createBookmark(BookmarkModel bookmark) async {
    final db = await instance.database;
    return await db.insert('bookmarks', bookmark.toMap());
  }

  Future<List<BookmarkModel>> getBookmarks([String? filePath]) async {
    final db = await instance.database;
    final maps = await db.query(
      'bookmarks',
      where: filePath != null ? 'filePath = ?' : null,
      whereArgs: filePath != null ? [filePath] : null,
      orderBy: filePath != null ? 'pageNumber ASC' : 'createdAt DESC',
    );
    return maps.map((e) => BookmarkModel.fromMap(e)).toList();
  }

  Future<int> updateBookmark(BookmarkModel bookmark) async {
    final db = await instance.database;
    return await db.update(
      'bookmarks',
      bookmark.toMap(),
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  Future<int> deleteBookmark(int id) async {
    final db = await instance.database;
    return await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ PDF FILES (Recent)
  Future<int> savePdfFile(PdfFileModel pdfFile) async {
    final db = await instance.database;

    final existing = await db.query(
      'pdf_files',
      where: 'filePath = ?',
      whereArgs: [pdfFile.filePath],
    );

    final map = pdfFile.toMap();
    map.remove('id'); // Prevent datatype mismatch

    if (existing.isNotEmpty) {
      // Preserve reading progress
      final oldLastPageRead = existing.first['lastPageRead'] as int? ?? 0;
      if (pdfFile.lastPageRead == 0 && oldLastPageRead > 0) {
        map['lastPageRead'] = oldLastPageRead;
      }

      return await db.update(
        'pdf_files',
        map,
        where: 'filePath = ?',
        whereArgs: [pdfFile.filePath],
      );
    } else {
      return await db.insert('pdf_files', map);
    }
  }

  Future<List<PdfFileModel>> getRecentFiles() async {
    final db = await instance.database;
    final maps = await db.query(
      'pdf_files',
      orderBy: 'lastOpened DESC',
      limit: 10,
    );
    return maps.map((e) => PdfFileModel.fromMap(e)).toList();
  }

  Future<PdfFileModel?> getPdfFile(String filePath) async {
    final db = await instance.database;
    final maps = await db.query(
      'pdf_files',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );

    if (maps.isNotEmpty) {
      return PdfFileModel.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateLastPage(String filePath, int pageNumber) async {
    final db = await instance.database;
    await db.update(
      'pdf_files',
      {
        'lastPageRead': pageNumber,
        'lastOpened': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
  }

  Future<int> deletePdfFile(String filePath) async {
    final db = await instance.database;
    return await db.delete(
      'pdf_files',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
  }

  Future<int> deleteAllPdfFiles() async {
    final db = await instance.database;
    return await db.delete('pdf_files');
  }

  // ✅ HIGHLIGHTS
  Future<int> createHighlight(TextHighlight highlight) async {
    final db = await instance.database;
    return await db.insert('highlights', highlight.toMap());
  }

  Future<List<TextHighlight>> getHighlights([String? filePath]) async {
    final db = await instance.database;
    final maps = await db.query(
      'highlights',
      where: filePath != null ? 'filePath = ?' : null,
      whereArgs: filePath != null ? [filePath] : null,
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => TextHighlight.fromMap(e)).toList();
  }

  Future<int> deleteHighlight(int id) async {
    final db = await instance.database;
    return await db.delete('highlights', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ UNDERLINES
  Future<int> createUnderline(TextUnderline underline) async {
    final db = await instance.database;
    return await db.insert('underlines', underline.toMap());
  }

  Future<List<TextUnderline>> getUnderlines([String? filePath]) async {
    final db = await instance.database;
    final maps = await db.query(
      'underlines',
      where: filePath != null ? 'filePath = ?' : null,
      whereArgs: filePath != null ? [filePath] : null,
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => TextUnderline.fromMap(e)).toList();
  }

  Future<int> deleteUnderline(int id) async {
    final db = await instance.database;
    return await db.delete('underlines', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ NOTES
  Future<int> createNote(PdfNote note) async {
    final db = await instance.database;
    return await db.insert('notes', note.toMap());
  }

  Future<List<PdfNote>> getNotes([String? filePath]) async {
    final db = await instance.database;
    final maps = await db.query(
      'notes',
      where: filePath != null ? 'filePath = ?' : null,
      whereArgs: filePath != null ? [filePath] : null,
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => PdfNote.fromMap(e)).toList();
  }

  Future<int> updateNote(PdfNote note) async {
    final db = await instance.database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Drawing Methods ====================

  /// Save a drawing path to database
  Future<int> saveDrawing(DrawingPath drawing) async {
    final db = await instance.database;
    return await db.insert('drawings', drawing.toMap());
  }

  /// Get all drawings for a specific file and page
  Future<List<DrawingPath>> getDrawingsByPage(
    String filePath,
    int pageNumber,
  ) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drawings',
      where: 'filePath = ? AND pageNumber = ?',
      whereArgs: [filePath, pageNumber],
      orderBy: 'createdAt ASC',
    );
    return List.generate(maps.length, (i) => DrawingPath.fromMap(maps[i]));
  }

  /// Get all drawings for a specific file
  Future<List<DrawingPath>> getDrawingsByFile(String filePath) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drawings',
      where: 'filePath = ?',
      whereArgs: [filePath],
      orderBy: 'pageNumber ASC, createdAt ASC',
    );
    return List.generate(maps.length, (i) => DrawingPath.fromMap(maps[i]));
  }

  /// Delete a specific drawing
  Future<int> deleteDrawing(int id) async {
    final db = await instance.database;
    return await db.delete('drawings', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all drawings for a specific file
  Future<int> deleteDrawingsByFile(String filePath) async {
    final db = await instance.database;
    return await db.delete(
      'drawings',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
  }

  /// Delete all drawings for a specific page
  Future<int> deleteDrawingsByPage(String filePath, int pageNumber) async {
    final db = await instance.database;
    return await db.delete(
      'drawings',
      where: 'filePath = ? AND pageNumber = ?',
      whereArgs: [filePath, pageNumber],
    );
  }

  // ==================== Signature Placement Methods ====================

  /// Save a signature placement to database
  Future<int> saveSignaturePlacement(SignaturePlacement placement) async {
    final db = await instance.database;
    return await db.insert('signature_placements', placement.toMap());
  }

  /// Get all signature placements for a specific file and page
  Future<List<SignaturePlacement>> getSignaturePlacementsByPage(
    String filePath,
    int pageNumber,
  ) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'signature_placements',
      where: 'filePath = ? AND pageNumber = ?',
      whereArgs: [filePath, pageNumber],
      orderBy: 'createdAt ASC',
    );
    return List.generate(
      maps.length,
      (i) => SignaturePlacement.fromMap(maps[i]),
    );
  }

  /// Get all signature placements for a specific file
  Future<List<SignaturePlacement>> getSignaturePlacementsByFile(
    String filePath,
  ) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'signature_placements',
      where: 'filePath = ?',
      whereArgs: [filePath],
      orderBy: 'pageNumber ASC, createdAt ASC',
    );
    return List.generate(
      maps.length,
      (i) => SignaturePlacement.fromMap(maps[i]),
    );
  }

  /// Update a signature placement
  Future<int> updateSignaturePlacement(SignaturePlacement placement) async {
    final db = await instance.database;
    return await db.update(
      'signature_placements',
      placement.toMap(),
      where: 'id = ?',
      whereArgs: [placement.id],
    );
  }

  /// Delete a specific signature placement
  Future<int> deleteSignaturePlacement(int id) async {
    final db = await instance.database;
    return await db.delete(
      'signature_placements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all signature placements for a specific file
  Future<int> deleteSignaturePlacementsByFile(String filePath) async {
    final db = await instance.database;
    return await db.delete(
      'signature_placements',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
  }

  // ✅ STRIKETHROUGHS
  Future<int> createStrikethrough(TextStrikethrough strikethrough) async {
    final db = await instance.database;
    return await db.insert('strikethroughs', strikethrough.toMap());
  }

  Future<List<TextStrikethrough>> getStrikethroughs([String? filePath]) async {
    final db = await instance.database;
    final maps = await db.query(
      'strikethroughs',
      where: filePath != null ? 'filePath = ?' : null,
      whereArgs: filePath != null ? [filePath] : null,
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => TextStrikethrough.fromMap(e)).toList();
  }

  Future<int> deleteStrikethrough(int id) async {
    final db = await instance.database;
    return await db.delete('strikethroughs', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ SQUIGGLIES
  Future<int> createSquiggly(TextSquiggly squiggly) async {
    final db = await instance.database;
    return await db.insert('squigglies', squiggly.toMap());
  }

  Future<List<TextSquiggly>> getSquigglies([String? filePath]) async {
    final db = await instance.database;
    final maps = await db.query(
      'squigglies',
      where: filePath != null ? 'filePath = ?' : null,
      whereArgs: filePath != null ? [filePath] : null,
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => TextSquiggly.fromMap(e)).toList();
  }

  Future<int> deleteSquiggly(int id) async {
    final db = await instance.database;
    return await db.delete('squigglies', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
