import 'dart:io';
import 'package:get_storage/get_storage.dart';

/// Service for smart resume functionality
class SmartResumeService {
  static final SmartResumeService instance = SmartResumeService._init();

  final GetStorage _storage = GetStorage();
  static const String _resumeDataKey = 'smart_resume_data';
  static const String _resumeSettingsKey = 'smart_resume_settings';

  SmartResumeService._init();

  /// Initialize service
  Future<void> init() async {
    await GetStorage.init();
  }

  /// Save reading session
  Future<void> saveReadingSession(
    String filePath,
    int currentPage,
    int totalPages, {
    int? scrollPosition,
    double? zoomLevel,
  }) async {
    try {
      final resumeData = _getResumeData();

      resumeData[filePath] = {
        'filePath': filePath,
        'fileName': _getFileName(filePath),
        'currentPage': currentPage,
        'totalPages': totalPages,
        'scrollPosition': scrollPosition,
        'zoomLevel': zoomLevel,
        'lastRead': DateTime.now().millisecondsSinceEpoch,
        'readingProgress': (currentPage / totalPages * 100).toInt(),
      };

      await _storage.write(_resumeDataKey, resumeData);
    } catch (e) {
      print('Error saving reading session: $e');
    }
  }

  /// Get reading session
  Map<String, dynamic>? getReadingSession(String filePath) {
    try {
      final resumeData = _getResumeData();
      return resumeData[filePath];
    } catch (e) {
      print('Error getting reading session: $e');
      return null;
    }
  }

  /// Check if should show resume prompt
  bool shouldShowResumePrompt(String filePath) {
    try {
      if (!isResumeEnabled()) return false;

      final session = getReadingSession(filePath);
      if (session == null) return false;

      final currentPage = session['currentPage'] as int? ?? 0;
      final totalPages = session['totalPages'] as int? ?? 0;

      // Don't show if on first page or last page
      if (currentPage <= 0 || currentPage >= totalPages - 1) return false;

      // Check if enough time has passed since last read
      final lastRead = session['lastRead'] as int?;
      if (lastRead != null) {
        final timeSinceLastRead =
            DateTime.now().millisecondsSinceEpoch - lastRead;
        final minTimeBetweenPrompts = getMinTimeBetweenPrompts();

        // Only show if at least X minutes have passed
        if (timeSinceLastRead < minTimeBetweenPrompts) return false;
      }

      return true;
    } catch (e) {
      print('Error checking resume prompt: $e');
      return false;
    }
  }

  /// Get resume message
  String getResumeMessage(String filePath) {
    try {
      final session = getReadingSession(filePath);
      if (session == null) return '';

      final currentPage = session['currentPage'] as int? ?? 0;
      final totalPages = session['totalPages'] as int? ?? 0;
      final progress = session['readingProgress'] as int? ?? 0;

      return 'Continue reading from page ${currentPage + 1} of $totalPages ($progress% complete)?';
    } catch (e) {
      return 'Continue reading where you left off?';
    }
  }

  /// Get all reading sessions
  List<Map<String, dynamic>> getAllReadingSessions() {
    try {
      final resumeData = _getResumeData();
      final sessions = resumeData.values.toList().cast<Map<String, dynamic>>();

      // Sort by last read time (most recent first)
      sessions.sort((a, b) {
        final aTime = a['lastRead'] as int? ?? 0;
        final bTime = b['lastRead'] as int? ?? 0;
        return bTime.compareTo(aTime);
      });

      return sessions;
    } catch (e) {
      print('Error getting all reading sessions: $e');
      return [];
    }
  }

  /// Get recently read files
  List<Map<String, dynamic>> getRecentlyReadFiles({int limit = 10}) {
    try {
      final sessions = getAllReadingSessions();
      return sessions.take(limit).toList();
    } catch (e) {
      print('Error getting recently read files: $e');
      return [];
    }
  }

  /// Get in-progress files (not finished)
  List<Map<String, dynamic>> getInProgressFiles() {
    try {
      final sessions = getAllReadingSessions();
      return sessions.where((session) {
        final currentPage = session['currentPage'] as int? ?? 0;
        final totalPages = session['totalPages'] as int? ?? 0;
        final progress = (currentPage / totalPages * 100).toInt();
        return progress > 0 && progress < 95; // Consider 95%+ as finished
      }).toList();
    } catch (e) {
      print('Error getting in-progress files: $e');
      return [];
    }
  }

  /// Get finished files
  List<Map<String, dynamic>> getFinishedFiles() {
    try {
      final sessions = getAllReadingSessions();
      return sessions.where((session) {
        final currentPage = session['currentPage'] as int? ?? 0;
        final totalPages = session['totalPages'] as int? ?? 0;
        final progress = (currentPage / totalPages * 100).toInt();
        return progress >= 95;
      }).toList();
    } catch (e) {
      print('Error getting finished files: $e');
      return [];
    }
  }

  /// Clear reading session
  Future<void> clearReadingSession(String filePath) async {
    try {
      final resumeData = _getResumeData();
      resumeData.remove(filePath);
      await _storage.write(_resumeDataKey, resumeData);
    } catch (e) {
      print('Error clearing reading session: $e');
    }
  }

  /// Clear all reading sessions
  Future<void> clearAllReadingSessions() async {
    try {
      await _storage.remove(_resumeDataKey);
    } catch (e) {
      print('Error clearing all reading sessions: $e');
    }
  }

  /// Clear old sessions (not read in X days)
  Future<void> clearOldSessions({int daysOld = 90}) async {
    try {
      final resumeData = _getResumeData();
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoffTime = now - (daysOld * 24 * 60 * 60 * 1000);

      final filesToRemove = <String>[];

      resumeData.forEach((filePath, data) {
        final lastRead = data['lastRead'] as int;
        if (lastRead < cutoffTime) {
          filesToRemove.add(filePath);
        }
      });

      for (final filePath in filesToRemove) {
        resumeData.remove(filePath);
      }

      await _storage.write(_resumeDataKey, resumeData);
    } catch (e) {
      print('Error clearing old sessions: $e');
    }
  }

  /// Get reading statistics
  Map<String, dynamic> getReadingStats() {
    try {
      final sessions = getAllReadingSessions();
      final inProgress = getInProgressFiles();
      final finished = getFinishedFiles();

      int totalPagesRead = 0;
      int totalBooks = sessions.length;

      for (final session in sessions) {
        totalPagesRead += (session['currentPage'] as int? ?? 0);
      }

      return {
        'totalBooks': totalBooks,
        'inProgress': inProgress.length,
        'finished': finished.length,
        'totalPagesRead': totalPagesRead,
        'averageProgress': totalBooks > 0
            ? sessions
                      .map((s) => s['readingProgress'] as int? ?? 0)
                      .reduce((a, b) => a + b) /
                  totalBooks
            : 0,
      };
    } catch (e) {
      print('Error getting reading stats: $e');
      return {};
    }
  }

  // ==================== Settings ====================

  /// Enable/disable smart resume
  Future<void> setResumeEnabled(bool enabled) async {
    try {
      final settings = _getResumeSettings();
      settings['enabled'] = enabled;
      await _storage.write(_resumeSettingsKey, settings);
    } catch (e) {
      print('Error setting resume enabled: $e');
    }
  }

  /// Check if resume is enabled
  bool isResumeEnabled() {
    try {
      final settings = _getResumeSettings();
      return settings['enabled'] as bool? ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Set minimum time between prompts (in milliseconds)
  Future<void> setMinTimeBetweenPrompts(int milliseconds) async {
    try {
      final settings = _getResumeSettings();
      settings['minTimeBetweenPrompts'] = milliseconds;
      await _storage.write(_resumeSettingsKey, settings);
    } catch (e) {
      print('Error setting min time between prompts: $e');
    }
  }

  /// Get minimum time between prompts
  int getMinTimeBetweenPrompts() {
    try {
      final settings = _getResumeSettings();
      return settings['minTimeBetweenPrompts'] as int? ??
          (5 * 60 * 1000); // Default 5 minutes
    } catch (e) {
      return 5 * 60 * 1000;
    }
  }

  /// Set auto-save interval (in seconds)
  Future<void> setAutoSaveInterval(int seconds) async {
    try {
      final settings = _getResumeSettings();
      settings['autoSaveInterval'] = seconds;
      await _storage.write(_resumeSettingsKey, settings);
    } catch (e) {
      print('Error setting auto-save interval: $e');
    }
  }

  /// Get auto-save interval
  int getAutoSaveInterval() {
    try {
      final settings = _getResumeSettings();
      return settings['autoSaveInterval'] as int? ?? 30; // Default 30 seconds
    } catch (e) {
      return 30;
    }
  }

  // ==================== Private Helper Methods ====================

  Map<String, dynamic> _getResumeData() {
    try {
      final data = _storage.read(_resumeDataKey);
      if (data == null) return {};
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e) {
      print('Error getting resume data: $e');
      return {};
    }
  }

  Map<String, dynamic> _getResumeSettings() {
    try {
      final data = _storage.read(_resumeSettingsKey);
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
