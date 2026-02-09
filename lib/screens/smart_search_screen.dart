import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartSearchScreen extends StatefulWidget {
  final String fullText;

  const SmartSearchScreen({Key? key, required this.fullText}) : super(key: key);

  @override
  State<SmartSearchScreen> createState() => _SmartSearchScreenState();
}

class _SmartSearchScreenState extends State<SmartSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchMatch> _searchResults = [];
  int _currentMatchIndex = -1;
  bool _caseSensitive = false;
  bool _wholeWord = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final List<SearchMatch> matches = [];
    String searchText = widget.fullText;
    String searchQuery = query;

    if (!_caseSensitive) {
      searchText = searchText.toLowerCase();
      searchQuery = searchQuery.toLowerCase();
    }

    int startIndex = 0;
    while (true) {
      final index = searchText.indexOf(searchQuery, startIndex);
      if (index == -1) break;

      // Check for whole word match if enabled
      if (_wholeWord) {
        final beforeChar = index > 0 ? searchText[index - 1] : ' ';
        final afterChar = index + searchQuery.length < searchText.length
            ? searchText[index + searchQuery.length]
            : ' ';

        if (!_isWordBoundary(beforeChar) || !_isWordBoundary(afterChar)) {
          startIndex = index + 1;
          continue;
        }
      }

      // Extract context around the match
      final contextStart = (index - 50).clamp(0, searchText.length);
      final contextEnd = (index + searchQuery.length + 50).clamp(
        0,
        searchText.length,
      );
      final context = widget.fullText.substring(contextStart, contextEnd);

      matches.add(
        SearchMatch(
          index: index,
          matchText: widget.fullText.substring(
            index,
            index + searchQuery.length,
          ),
          context: context,
          contextStart: contextStart,
        ),
      );

      startIndex = index + 1;
    }

    setState(() {
      _searchResults = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
  }

  bool _isWordBoundary(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == '.' ||
        char == ',' ||
        char == ';' ||
        char == ':' ||
        char == '!' ||
        char == '?';
  }

  void _nextMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchResults.length;
    });
  }

  void _previousMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _searchResults.length) %
          _searchResults.length;
    });
  }

  void _copyCurrentMatch() {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _searchResults.length) {
      final match = _searchResults[_currentMatchIndex];
      Clipboard.setData(ClipboardData(text: match.context));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Context copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Search'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Search Tips'),
                    ],
                  ),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🔍 Search Features:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('• Case-sensitive search option'),
                        Text('• Whole word matching'),
                        Text('• Context preview for each match'),
                        Text('• Navigate between results'),
                        Text('• Copy context to clipboard'),
                        SizedBox(height: 16),
                        Text(
                          '💡 Tips:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('• Use whole word for exact matches'),
                        Text('• Toggle case sensitivity as needed'),
                        Text('• Use arrow buttons to navigate'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search TextField
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search in document...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.white,
                  ),
                  onChanged: _performSearch,
                ),
                const SizedBox(height: 12),
                // Search Options
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Case sensitive'),
                        value: _caseSensitive,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            _caseSensitive = value ?? false;
                          });
                          _performSearch(_searchController.text);
                        },
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Whole word'),
                        value: _wholeWord,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            _wholeWord = value ?? false;
                          });
                          _performSearch(_searchController.text);
                        },
                      ),
                    ),
                  ],
                ),
                // Results Counter and Navigation
                if (_searchResults.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Match ${_currentMatchIndex + 1} of ${_searchResults.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward),
                              onPressed: _previousMatch,
                              tooltip: 'Previous match',
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              onPressed: _nextMatch,
                              tooltip: 'Next match',
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: _copyCurrentMatch,
                              tooltip: 'Copy context',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Results List
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Enter a search term to begin',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search options',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final match = _searchResults[index];
        final isSelected = index == _currentMatchIndex;

        return Card(
          elevation: isSelected ? 4 : 1,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : null,
          child: InkWell(
            onTap: () {
              setState(() {
                _currentMatchIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Position: ${match.index}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildHighlightedContext(
                    match.context,
                    _searchController.text,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedContext(String context, String query) {
    if (query.isEmpty) {
      return Text(context);
    }

    final spans = <TextSpan>[];
    String searchText = context;
    String searchQuery = query;

    if (!_caseSensitive) {
      searchText = searchText.toLowerCase();
      searchQuery = searchQuery.toLowerCase();
    }

    int lastIndex = 0;
    int startIndex = 0;

    while (true) {
      final index = searchText.indexOf(searchQuery, startIndex);
      if (index == -1) break;

      // Add text before match
      if (index > lastIndex) {
        spans.add(
          TextSpan(
            text: context.substring(lastIndex, index),
            style: const TextStyle(color: Colors.grey),
          ),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: context.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: Colors.yellow[700],
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      lastIndex = index + query.length;
      startIndex = lastIndex;
    }

    // Add remaining text
    if (lastIndex < context.length) {
      spans.add(
        TextSpan(
          text: context.substring(lastIndex),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }
}

class SearchMatch {
  final int index;
  final String matchText;
  final String context;
  final int contextStart;

  SearchMatch({
    required this.index,
    required this.matchText,
    required this.context,
    required this.contextStart,
  });
}
