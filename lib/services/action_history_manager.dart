/// Types of actions that can be undone/redone
enum ActionType {
  addDrawing,
  removeDrawing,
  addHighlight,
  removeHighlight,
  addNote,
  removeNote,
  addSignature,
  removeSignature,
  addUnderline,
  removeUnderline,
  addStrikethrough,
  removeStrikethrough,
  addSquiggly,
  removeSquiggly,
}

/// Represents a single action in the history
class HistoryAction {
  final ActionType type;
  dynamic data;
  final DateTime timestamp;

  HistoryAction({required this.type, required this.data})
    : timestamp = DateTime.now();

  @override
  String toString() {
    return 'HistoryAction(type: $type, timestamp: $timestamp)';
  }
}

/// Manages undo/redo history for PDF annotations
class ActionHistoryManager {
  final List<HistoryAction> _undoStack = [];
  final List<HistoryAction> _redoStack = [];
  final int maxHistorySize;

  ActionHistoryManager({this.maxHistorySize = 50});

  /// Add a new action to the history
  void addAction(HistoryAction action) {
    _undoStack.add(action);
    _redoStack.clear(); // Clear redo stack when new action is added

    // Limit history size to prevent memory issues
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo the last action
  HistoryAction? undo() {
    if (_undoStack.isEmpty) return null;

    final action = _undoStack.removeLast();
    _redoStack.add(action);
    return action;
  }

  /// Redo the last undone action
  HistoryAction? redo() {
    if (_redoStack.isEmpty) return null;

    final action = _redoStack.removeLast();
    _undoStack.add(action);
    return action;
  }

  /// Check if undo is available
  bool get canUndo => _undoStack.isNotEmpty;

  /// Check if redo is available
  bool get canRedo => _redoStack.isNotEmpty;

  /// Get the number of actions in undo stack
  int get undoCount => _undoStack.length;

  /// Get the number of actions in redo stack
  int get redoCount => _redoStack.length;

  /// Clear all history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Get a preview of the last action (for UI display)
  String? getLastActionDescription() {
    if (_undoStack.isEmpty) return null;

    final action = _undoStack.last;
    switch (action.type) {
      case ActionType.addDrawing:
        return 'Drawing added';
      case ActionType.removeDrawing:
        return 'Drawing removed';
      case ActionType.addHighlight:
        return 'Highlight added';
      case ActionType.removeHighlight:
        return 'Highlight removed';
      case ActionType.addNote:
        return 'Note added';
      case ActionType.removeNote:
        return 'Note removed';
      case ActionType.addSignature:
        return 'Signature added';
      case ActionType.removeSignature:
        return 'Signature removed';
      case ActionType.addUnderline:
        return 'Underline added';
      case ActionType.removeUnderline:
        return 'Underline removed';
      case ActionType.addStrikethrough:
        return 'Strikethrough added';
      case ActionType.removeStrikethrough:
        return 'Strikethrough removed';
      case ActionType.addSquiggly:
        return 'Squiggly added';
      case ActionType.removeSquiggly:
        return 'Squiggly removed';
    }
  }
}
