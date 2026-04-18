import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;

class FileHelper {
  /// Format file size to human-readable string
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";

    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();

    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Get file extension
  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// Get file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  /// Get file name with extension
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Check if file exists
  static Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (_) {
      return false;
    }
  }

  /// Get file size in bytes
  static Future<int> getFileSize(String filePath) async {
    try {
      return await File(filePath).length();
    } catch (_) {
      return 0;
    }
  }

  /// Get file's last modified timestamp
  static Future<DateTime?> getLastModified(String filePath) async {
    try {
      return await File(filePath).lastModified();
    } catch (_) {
      return null;
    }
  }

  /// Check if a file is a PDF
  static bool isPdfFile(String filePath) {
    return getFileExtension(filePath) == '.pdf';
  }

  /// Create directory if it doesn't exist
  static Future<void> createDirectoryIfNotExists(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Safely delete a file
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Copy file to another path
  static Future<bool> copyFile(
    String sourcePath,
    String destinationPath,
  ) async {
    try {
      final sourceFile = File(sourcePath);
      final destinationFile = File(destinationPath);
      await createDirectoryIfNotExists(destinationFile.parent.path);
      await sourceFile.copy(destinationPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Move file to another path
  static Future<bool> moveFile(
    String sourcePath,
    String destinationPath,
  ) async {
    try {
      final sourceFile = File(sourcePath);
      final destinationFile = File(destinationPath);
      await createDirectoryIfNotExists(destinationFile.parent.path);
      await sourceFile.rename(destinationPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get system temporary path with file name
  static String getTempFilePath(String fileName) {
    final tempDir = Directory.systemTemp;
    return path.join(tempDir.path, fileName);
  }

  /// Clean invalid characters from a file name
  static String cleanFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  /// Get MIME type based on extension
  static String getMimeType(String filePath) {
    final ext = getFileExtension(filePath);
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Format date difference as relative time
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 7) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if file path is valid
  static bool isValidFilePath(String filePath) {
    return filePath.trim().isNotEmpty;
  }

  /// Dummy implementation: available space check (needs platform-specific implementation)
  static Future<int> getAvailableSpace(String directoryPath) async {
    // This is a placeholder. Platform channels or plugins like disk_space_plus are required.
    return 0;
  }

  /// Check if enough disk space is available
  static Future<bool> hasEnoughSpace(
    String directoryPath,
    int requiredBytes,
  ) async {
    final available = await getAvailableSpace(directoryPath);
    return available >= requiredBytes;
  }
}
