/// Reading statistics model
class ReadingStats {
  final int wordsRead;
  final int sentencesRead;
  final Duration readingTime;
  final int currentPage;
  final int totalPages;

  ReadingStats({
    required this.wordsRead,
    required this.sentencesRead,
    required this.readingTime,
    required this.currentPage,
    required this.totalPages,
  });

  double get wordsPerMinute {
    if (readingTime.inSeconds == 0) return 0;
    return (wordsRead / readingTime.inSeconds) * 60;
  }

  double get progress {
    if (totalPages == 0) return 0;
    return currentPage / totalPages;
  }

  String get formattedTime {
    final hours = readingTime.inHours;
    final minutes = readingTime.inMinutes.remainder(60);
    final seconds = readingTime.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
