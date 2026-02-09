import 'dart:io';
import 'package:get_storage/get_storage.dart';

/// Service for managing offline PDF cache
class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._init();

  final GetStorage _storage = GetStorage();
  static const String _cacheMetadataKey = 'pdf_cache_metadata';
  static const String _cacheSettingsKey = 'cache_settings';

  OfflineCacheService._init();

  /// Initialize cache service
  Future<void> init() async {
    await GetStorage.init();
  }

  /// Add file to cache
  Future<void> addToCache(
    String filePath, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final cacheMetadata = _getCacheMetadata();
      final fileSize = await file.length();

      cacheMetadata[filePath] = {
        'filePath': filePath,
        'fileName': _getFileName(filePath),
        'fileSize': fileSize,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'lastAccessed': DateTime.now().millisecondsSinceEpoch,
        'accessCount': 0,
        ...?metadata,
      };

      await _storage.write(_cacheMetadataKey, cacheMetadata);
    } catch (e) {
      print('Error adding to cache: $e');
      rethrow;
    }
  }

  /// Remove file from cache
  Future<void> removeFromCache(String filePath) async {
    try {
      final cacheMetadata = _getCacheMetadata();
      cacheMetadata.remove(filePath);
      await _storage.write(_cacheMetadataKey, cacheMetadata);
    } catch (e) {
      print('Error removing from cache: $e');
    }
  }

  /// Update last accessed time
  Future<void> updateLastAccessed(String filePath) async {
    try {
      final cacheMetadata = _getCacheMetadata();
      if (cacheMetadata.containsKey(filePath)) {
        cacheMetadata[filePath]['lastAccessed'] =
            DateTime.now().millisecondsSinceEpoch;
        cacheMetadata[filePath]['accessCount'] =
            (cacheMetadata[filePath]['accessCount'] ?? 0) + 1;
        await _storage.write(_cacheMetadataKey, cacheMetadata);
      }
    } catch (e) {
      print('Error updating last accessed: $e');
    }
  }

  /// Get all cached files
  List<Map<String, dynamic>> getCachedFiles() {
    try {
      final cacheMetadata = _getCacheMetadata();
      return cacheMetadata.values.toList().cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting cached files: $e');
      return [];
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final cachedFiles = getCachedFiles();
      int totalSize = 0;

      for (final fileData in cachedFiles) {
        final filePath = fileData['filePath'] as String;
        final file = File(filePath);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }

  /// Get cache size in MB
  Future<double> getCacheSizeMB() async {
    final bytes = await getCacheSize();
    return bytes / (1024 * 1024);
  }

  /// Clear cache
  Future<void> clearCache({bool deleteFiles = false}) async {
    try {
      if (deleteFiles) {
        final cachedFiles = getCachedFiles();
        for (final fileData in cachedFiles) {
          final filePath = fileData['filePath'] as String;
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      await _storage.remove(_cacheMetadataKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Clear old cache (files not accessed in X days)
  Future<void> clearOldCache({
    int daysOld = 30,
    bool deleteFiles = false,
  }) async {
    try {
      final cacheMetadata = _getCacheMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoffTime = now - (daysOld * 24 * 60 * 60 * 1000);

      final filesToRemove = <String>[];

      cacheMetadata.forEach((filePath, data) {
        final lastAccessed = data['lastAccessed'] as int;
        if (lastAccessed < cutoffTime) {
          filesToRemove.add(filePath);
        }
      });

      for (final filePath in filesToRemove) {
        if (deleteFiles) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        cacheMetadata.remove(filePath);
      }

      await _storage.write(_cacheMetadataKey, cacheMetadata);
    } catch (e) {
      print('Error clearing old cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cachedFiles = getCachedFiles();
      final cacheSize = await getCacheSize();
      final cacheSizeMB = cacheSize / (1024 * 1024);

      int totalAccesses = 0;
      for (final file in cachedFiles) {
        totalAccesses += (file['accessCount'] as int?) ?? 0;
      }

      return {
        'totalFiles': cachedFiles.length,
        'totalSizeBytes': cacheSize,
        'totalSizeMB': cacheSizeMB,
        'totalAccesses': totalAccesses,
        'averageFileSize': cachedFiles.isNotEmpty
            ? cacheSize / cachedFiles.length
            : 0,
      };
    } catch (e) {
      print('Error getting cache stats: $e');
      return {};
    }
  }

  /// Check if file is cached
  bool isFileCached(String filePath) {
    final cacheMetadata = _getCacheMetadata();
    return cacheMetadata.containsKey(filePath);
  }

  /// Get most accessed files
  List<Map<String, dynamic>> getMostAccessedFiles({int limit = 10}) {
    try {
      final cachedFiles = getCachedFiles();
      cachedFiles.sort((a, b) {
        final aCount = (a['accessCount'] as int?) ?? 0;
        final bCount = (b['accessCount'] as int?) ?? 0;
        return bCount.compareTo(aCount);
      });
      return cachedFiles.take(limit).toList();
    } catch (e) {
      print('Error getting most accessed files: $e');
      return [];
    }
  }

  /// Get recently accessed files
  List<Map<String, dynamic>> getRecentlyAccessedFiles({int limit = 10}) {
    try {
      final cachedFiles = getCachedFiles();
      cachedFiles.sort((a, b) {
        final aTime = (a['lastAccessed'] as int?) ?? 0;
        final bTime = (b['lastAccessed'] as int?) ?? 0;
        return bTime.compareTo(aTime);
      });
      return cachedFiles.take(limit).toList();
    } catch (e) {
      print('Error getting recently accessed files: $e');
      return [];
    }
  }

  /// Set cache size limit (in MB)
  Future<void> setCacheSizeLimit(double limitMB) async {
    try {
      final settings = _getCacheSettings();
      settings['sizeLimitMB'] = limitMB;
      await _storage.write(_cacheSettingsKey, settings);
    } catch (e) {
      print('Error setting cache size limit: $e');
    }
  }

  /// Get cache size limit
  double getCacheSizeLimit() {
    try {
      final settings = _getCacheSettings();
      return (settings['sizeLimitMB'] as num?)?.toDouble() ??
          500.0; // Default 500MB
    } catch (e) {
      return 500.0;
    }
  }

  /// Enforce cache size limit (remove least accessed files)
  Future<void> enforceCacheSizeLimit() async {
    try {
      final limit = getCacheSizeLimit();
      final currentSize = await getCacheSizeMB();

      if (currentSize > limit) {
        final cachedFiles = getCachedFiles();

        // Sort by access count (ascending) and last accessed (ascending)
        cachedFiles.sort((a, b) {
          final aCount = (a['accessCount'] as int?) ?? 0;
          final bCount = (b['accessCount'] as int?) ?? 0;
          if (aCount != bCount) {
            return aCount.compareTo(bCount);
          }
          final aTime = (a['lastAccessed'] as int?) ?? 0;
          final bTime = (b['lastAccessed'] as int?) ?? 0;
          return aTime.compareTo(bTime);
        });

        // Remove files until under limit
        double removedSize = 0;
        for (final fileData in cachedFiles) {
          if (currentSize - removedSize <= limit) break;

          final filePath = fileData['filePath'] as String;
          final fileSize = (fileData['fileSize'] as int?) ?? 0;

          await removeFromCache(filePath);
          removedSize += fileSize / (1024 * 1024);
        }
      }
    } catch (e) {
      print('Error enforcing cache size limit: $e');
    }
  }

  // ==================== Private Helper Methods ====================

  Map<String, dynamic> _getCacheMetadata() {
    try {
      final data = _storage.read(_cacheMetadataKey);
      if (data == null) return {};
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e) {
      print('Error getting cache metadata: $e');
      return {};
    }
  }

  Map<String, dynamic> _getCacheSettings() {
    try {
      final data = _storage.read(_cacheSettingsKey);
      if (data == null) return {};
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  String _getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }
}
