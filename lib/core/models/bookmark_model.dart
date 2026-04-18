class BookmarkModel {
  final int? id;
  final String fileName;
  final String filePath;
  final int pageNumber;
  final String title;
  final DateTime createdAt;
  final String? note;

  BookmarkModel({
    this.id,
    required this.fileName,
    required this.filePath,
    required this.pageNumber,
    required this.title,
    required this.createdAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'note': note,
    };
  }

  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id'],
      fileName: map['fileName'],
      filePath: map['filePath'],
      pageNumber: map['pageNumber'],
      title: map['title'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      note: map['note'],
    );
  }

  BookmarkModel copyWith({
    int? id,
    String? fileName,
    String? filePath,
    int? pageNumber,
    String? title,
    DateTime? createdAt,
    String? note,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      pageNumber: pageNumber ?? this.pageNumber,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }
}

class PdfFileModel {
  final int? id;
  final String fileName;
  final String filePath;
  final int totalPages;
  final int lastPageRead;
  final DateTime lastOpened;
  final int fileSize;

  PdfFileModel({
    this.id,
    required this.fileName,
    required this.filePath,
    required this.totalPages,
    this.lastPageRead = 0,
    required this.lastOpened,
    required this.fileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'totalPages': totalPages,
      'lastPageRead': lastPageRead,
      'lastOpened': lastOpened.millisecondsSinceEpoch,
      'fileSize': fileSize,
    };
  }

  factory PdfFileModel.fromMap(Map<String, dynamic> map) {
    return PdfFileModel(
      id: map['id'],
      fileName: map['fileName'],
      filePath: map['filePath'],
      totalPages: map['totalPages'],
      lastPageRead: map['lastPageRead'] ?? 0,
      lastOpened: DateTime.fromMillisecondsSinceEpoch(map['lastOpened']),
      fileSize: map['fileSize'],
    );
  }
}
