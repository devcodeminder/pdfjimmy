import 'dart:io';
import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';

import 'package:path/path.dart' as path;

/// Service for Google Drive cloud synchronization
/// Stores PDFs, reading progress, bookmarks, and annotations in Google Drive
class GoogleDriveCloudService {
  static final GoogleDriveCloudService instance =
      GoogleDriveCloudService._init();

  final GetStorage _storage = GetStorage();

  // Google Drive API
  drive.DriveApi? _driveApi;
  AutoRefreshingAuthClient? _authClient;

  // Storage keys
  static const String _syncEnabledKey = 'gdrive_sync_enabled';
  static const String _lastSyncKey = 'gdrive_last_sync_time';
  static const String _deviceIdKey = 'gdrive_device_id';
  static const String _credentialsKey = 'gdrive_credentials';
  static const String _appFolderIdKey = 'gdrive_app_folder_id';

  // Google Drive folder structure
  static const String _appFolderName = 'PDFJimmy';
  static const String _pdfsFolderName = 'PDFs';
  static const String _dataFolderName = 'Data';

  GoogleDriveCloudService._init();

  /// Initialize cloud sync
  Future<void> init() async {
    await GetStorage.init();
  }

  /// Check if user is signed in
  bool get isSignedIn => _driveApi != null;

  /// Enable/disable cloud sync
  Future<void> setSyncEnabled(bool enabled) async {
    await _storage.write(_syncEnabledKey, enabled);
  }

  /// Check if sync is enabled
  bool get isSyncEnabled => _storage.read(_syncEnabledKey) ?? false;

  /// Sign in to Google Drive
  /// You need to provide OAuth 2.0 credentials from Google Cloud Console
  Future<bool> signIn({
    required String clientId,
    required String clientSecret,
    List<String>? scopes,
  }) async {
    try {
      final credentials = ClientId(clientId, clientSecret);
      final authScopes = scopes ?? [drive.DriveApi.driveFileScope];

      // Get auth client
      _authClient = await clientViaUserConsent(
        credentials,
        authScopes,
        _promptUser,
      );

      // Initialize Drive API
      _driveApi = drive.DriveApi(_authClient!);

      // Create app folder structure
      await _createAppFolderStructure();

      // Save credentials
      await _saveCredentials();

      return true;
    } catch (e) {
      print('Error signing in to Google Drive: $e');
      return false;
    }
  }

  /// Sign out from Google Drive
  Future<void> signOut() async {
    try {
      _authClient?.close();
      _authClient = null;
      _driveApi = null;
      await _storage.remove(_credentialsKey);
      await setSyncEnabled(false);
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Upload PDF to Google Drive
  Future<String?> uploadPdf(String filePath) async {
    if (!isSyncEnabled || !isSignedIn) return null;

    try {
      final file = File(filePath);
      final fileName = path.basename(filePath);

      // Get PDFs folder ID
      final pdfsFolderId = await _getPdfsFolderId();
      if (pdfsFolderId == null) return null;

      // Check if file already exists
      final existingFileId = await _findFileByName(fileName, pdfsFolderId);

      // Create file metadata
      final driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.parents = [pdfsFolderId];
      driveFile.mimeType = 'application/pdf';

      // Upload file
      final media = drive.Media(file.openRead(), await file.length());

      drive.File? uploadedFile;
      if (existingFileId != null) {
        // Update existing file
        uploadedFile = await _driveApi!.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        // Create new file
        uploadedFile = await _driveApi!.files.create(
          driveFile,
          uploadMedia: media,
        );
      }

      await _updateLastSyncTime();
      return uploadedFile.id;
    } catch (e) {
      print('Error uploading PDF: $e');
      return null;
    }
  }

  /// Download PDF from Google Drive
  Future<String?> downloadPdf(String fileId, String savePath) async {
    if (!isSyncEnabled || !isSignedIn) return null;

    try {
      // Get file
      final media =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      // Save to file
      final file = File(savePath);
      final sink = file.openWrite();

      await for (var data in media.stream) {
        sink.add(data);
      }

      await sink.close();
      return savePath;
    } catch (e) {
      print('Error downloading PDF: $e');
      return null;
    }
  }

  /// Sync reading progress for a PDF
  Future<void> syncReadingProgress(
    String filePath,
    int currentPage,
    int totalPages,
  ) async {
    if (!isSyncEnabled || !isSignedIn) return;

    try {
      final fileName = path.basename(filePath);
      final dataFolderId = await _getDataFolderId();
      if (dataFolderId == null) return;

      final progressData = {
        'fileName': fileName,
        'filePath': filePath,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'lastRead': DateTime.now().millisecondsSinceEpoch,
        'deviceId': await _getDeviceId(),
      };

      // Save as JSON file
      final jsonFileName = '${fileName}_progress.json';
      await _uploadJsonData(jsonFileName, progressData, dataFolderId);

      await _updateLastSyncTime();
    } catch (e) {
      print('Error syncing reading progress: $e');
    }
  }

  /// Get reading progress from cloud
  Future<Map<String, dynamic>?> getReadingProgress(String filePath) async {
    if (!isSyncEnabled || !isSignedIn) return null;

    try {
      final fileName = path.basename(filePath);
      final dataFolderId = await _getDataFolderId();
      if (dataFolderId == null) return null;

      final jsonFileName = '${fileName}_progress.json';
      return await _downloadJsonData(jsonFileName, dataFolderId);
    } catch (e) {
      print('Error getting reading progress: $e');
      return null;
    }
  }

  /// Sync bookmarks
  Future<void> syncBookmarks(
    String filePath,
    List<Map<String, dynamic>> bookmarks,
  ) async {
    if (!isSyncEnabled || !isSignedIn) return;

    try {
      final fileName = path.basename(filePath);
      final dataFolderId = await _getDataFolderId();
      if (dataFolderId == null) return;

      final bookmarksData = {
        'fileName': fileName,
        'filePath': filePath,
        'bookmarks': bookmarks,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'deviceId': await _getDeviceId(),
      };

      final jsonFileName = '${fileName}_bookmarks.json';
      await _uploadJsonData(jsonFileName, bookmarksData, dataFolderId);

      await _updateLastSyncTime();
    } catch (e) {
      print('Error syncing bookmarks: $e');
    }
  }

  /// Get bookmarks from cloud
  Future<List<Map<String, dynamic>>> getBookmarks(String filePath) async {
    if (!isSyncEnabled || !isSignedIn) return [];

    try {
      final fileName = path.basename(filePath);
      final dataFolderId = await _getDataFolderId();
      if (dataFolderId == null) return [];

      final jsonFileName = '${fileName}_bookmarks.json';
      final data = await _downloadJsonData(jsonFileName, dataFolderId);

      if (data != null && data['bookmarks'] != null) {
        return (data['bookmarks'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting bookmarks: $e');
      return [];
    }
  }

  /// Sync annotations (highlights, notes)
  Future<void> syncAnnotations(
    String filePath,
    Map<String, dynamic> annotations,
  ) async {
    if (!isSyncEnabled || !isSignedIn) return;

    try {
      final fileName = path.basename(filePath);
      final dataFolderId = await _getDataFolderId();
      if (dataFolderId == null) return;

      final annotationsData = {
        'fileName': fileName,
        'filePath': filePath,
        'annotations': annotations,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'deviceId': await _getDeviceId(),
      };

      final jsonFileName = '${fileName}_annotations.json';
      await _uploadJsonData(jsonFileName, annotationsData, dataFolderId);

      await _updateLastSyncTime();
    } catch (e) {
      print('Error syncing annotations: $e');
    }
  }

  /// Get annotations from cloud
  Future<Map<String, dynamic>> getAnnotations(String filePath) async {
    if (!isSyncEnabled || !isSignedIn) return {};

    try {
      final fileName = path.basename(filePath);
      final dataFolderId = await _getDataFolderId();
      if (dataFolderId == null) return {};

      final jsonFileName = '${fileName}_annotations.json';
      final data = await _downloadJsonData(jsonFileName, dataFolderId);

      if (data != null && data['annotations'] != null) {
        return data['annotations'] as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error getting annotations: $e');
      return {};
    }
  }

  /// Get all synced PDFs
  Future<List<Map<String, dynamic>>> getSyncedPdfs() async {
    if (!isSyncEnabled || !isSignedIn) return [];

    try {
      final pdfsFolderId = await _getPdfsFolderId();
      if (pdfsFolderId == null) return [];

      final fileList = await _driveApi!.files.list(
        q: "'$pdfsFolderId' in parents and mimeType='application/pdf'",
        spaces: 'drive',
        $fields: 'files(id, name, size, modifiedTime)',
      );

      return fileList.files
              ?.map(
                (file) => {
                  'id': file.id,
                  'name': file.name,
                  'size': file.size,
                  'modifiedTime': file.modifiedTime?.millisecondsSinceEpoch,
                },
              )
              .toList() ??
          [];
    } catch (e) {
      print('Error getting synced PDFs: $e');
      return [];
    }
  }

  /// Delete all cloud data
  Future<void> deleteAllCloudData() async {
    if (!isSignedIn) return;

    try {
      final appFolderId = _storage.read(_appFolderIdKey);
      if (appFolderId != null) {
        await _driveApi!.files.delete(appFolderId);
        await _storage.remove(_appFolderIdKey);
      }
    } catch (e) {
      print('Error deleting cloud data: $e');
    }
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    final timestamp = _storage.read(_lastSyncKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  // ==================== Private Helper Methods ====================

  /// Create app folder structure in Google Drive
  Future<void> _createAppFolderStructure() async {
    try {
      // Check if app folder exists
      String? appFolderId = _storage.read(_appFolderIdKey);

      if (appFolderId == null) {
        // Create main app folder
        appFolderId = await _createFolder(_appFolderName, null);
        if (appFolderId != null) {
          await _storage.write(_appFolderIdKey, appFolderId);
        }
      }

      if (appFolderId != null) {
        // Create subfolders
        await _createFolder(_pdfsFolderName, appFolderId);
        await _createFolder(_dataFolderName, appFolderId);
      }
    } catch (e) {
      print('Error creating folder structure: $e');
    }
  }

  /// Create a folder in Google Drive
  Future<String?> _createFolder(String folderName, String? parentId) async {
    try {
      // Check if folder already exists
      final existingFolderId = await _findFileByName(folderName, parentId);
      if (existingFolderId != null) return existingFolderId;

      // Create new folder
      final folder = drive.File();
      folder.name = folderName;
      folder.mimeType = 'application/vnd.google-apps.folder';
      if (parentId != null) {
        folder.parents = [parentId];
      }

      final createdFolder = await _driveApi!.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      print('Error creating folder: $e');
      return null;
    }
  }

  /// Find file by name in a specific folder
  Future<String?> _findFileByName(String fileName, String? parentId) async {
    try {
      String query = "name='$fileName'";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      }

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
      return null;
    } catch (e) {
      print('Error finding file: $e');
      return null;
    }
  }

  /// Get PDFs folder ID
  Future<String?> _getPdfsFolderId() async {
    final appFolderId = _storage.read(_appFolderIdKey);
    if (appFolderId == null) return null;
    return await _findFileByName(_pdfsFolderName, appFolderId);
  }

  /// Get Data folder ID
  Future<String?> _getDataFolderId() async {
    final appFolderId = _storage.read(_appFolderIdKey);
    if (appFolderId == null) return null;
    return await _findFileByName(_dataFolderName, appFolderId);
  }

  /// Upload JSON data to Google Drive
  Future<void> _uploadJsonData(
    String fileName,
    Map<String, dynamic> data,
    String folderId,
  ) async {
    try {
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);

      // Check if file exists
      final existingFileId = await _findFileByName(fileName, folderId);

      final driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.parents = [folderId];
      driveFile.mimeType = 'application/json';

      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (existingFileId != null) {
        await _driveApi!.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        await _driveApi!.files.create(driveFile, uploadMedia: media);
      }
    } catch (e) {
      print('Error uploading JSON data: $e');
    }
  }

  /// Download JSON data from Google Drive
  Future<Map<String, dynamic>?> _downloadJsonData(
    String fileName,
    String folderId,
  ) async {
    try {
      final fileId = await _findFileByName(fileName, folderId);
      if (fileId == null) return null;

      final media =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final bytes = <int>[];
      await for (var data in media.stream) {
        bytes.addAll(data);
      }

      final jsonString = utf8.decode(bytes);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error downloading JSON data: $e');
      return null;
    }
  }

  /// Update last sync time
  Future<void> _updateLastSyncTime() async {
    await _storage.write(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get device ID
  Future<String> _getDeviceId() async {
    String? deviceId = _storage.read(_deviceIdKey);
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.write(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  /// Save credentials
  Future<void> _saveCredentials() async {
    // Note: In production, use secure storage
    // This is a simplified version
  }

  /// Prompt user for OAuth consent
  void _promptUser(String url) {
    print('Please go to the following URL and grant access:');
    print(url);
    print('');
  }
}
