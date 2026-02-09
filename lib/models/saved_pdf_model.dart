class SavedPdfModel {
  final String path;
  final String fileName;
  final DateTime dateAdded;
  final String? fileHash; // Optional: if we want to valid integrity

  SavedPdfModel({
    required this.path,
    required this.fileName,
    required this.dateAdded,
    this.fileHash,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'fileName': fileName,
    'dateAdded': dateAdded.toIso8601String(),
    'fileHash': fileHash,
  };

  factory SavedPdfModel.fromJson(Map<String, dynamic> json) => SavedPdfModel(
    path: json['path'],
    fileName: json['fileName'],
    dateAdded: DateTime.parse(json['dateAdded']),
    fileHash: json['fileHash'],
  );
}
