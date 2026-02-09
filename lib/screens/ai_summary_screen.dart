import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_pdf_service.dart';

class AISummaryScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AISummaryScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  State<AISummaryScreen> createState() => _AISummaryScreenState();
}

class _AISummaryScreenState extends State<AISummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  // Data
  List<String> _summaryBullets = [];
  List<Map<String, dynamic>> _pageSummaries = [];
  List<Map<String, dynamic>> _importantLines = [];
  Map<String, List<String>> _entities = {};
  Map<String, List<Map<String, dynamic>>> _highlights = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if service is running
      final isRunning = await AIPdfService.isServiceRunning();
      if (!isRunning) {
        throw Exception(
          'AI service is not running. Please start the Python server first.',
        );
      }

      // Get full analysis
      final result = await AIPdfService.analyzeFullPdf(widget.filePath);

      if (result['success'] == true) {
        setState(() {
          _summaryBullets = List<String>.from(
            result['full_summary']['bullets'],
          );
          _pageSummaries = List<Map<String, dynamic>>.from(
            result['page_summaries'],
          );
          _importantLines = List<Map<String, dynamic>>.from(
            result['important_lines'],
          );
          _entities = (result['entities'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          );
          _highlights =
              (result['categorized_highlights'] as Map<String, dynamic>).map(
                (key, value) =>
                    MapEntry(key, List<Map<String, dynamic>>.from(value)),
              );
          _isLoading = false;
        });
      } else {
        throw Exception('Analysis failed');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Analysis'),
            Text(widget.fileName, style: const TextStyle(fontSize: 12)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.summarize), text: 'Summary'),
            Tab(icon: Icon(Icons.pages), text: 'Pages'),
            Tab(icon: Icon(Icons.star), text: 'Important'),
            Tab(icon: Icon(Icons.label), text: 'Entities'),
            Tab(icon: Icon(Icons.highlight), text: 'Highlights'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalysis,
            tooltip: 'Refresh analysis',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _error != null
          ? _buildErrorView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildPageSummariesTab(),
                _buildImportantLinesTab(),
                _buildEntitiesTab(),
                _buildHighlightsTab(),
              ],
            ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Analyzing PDF with AI...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Analysis Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI-Generated Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._summaryBullets.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        final text = _summaryBullets
                            .asMap()
                            .entries
                            .map((e) => '${e.key + 1}. ${e.value}')
                            .join('\n\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Summary copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageSummariesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pageSummaries.length,
      itemBuilder: (context, index) {
        final page = _pageSummaries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                '${page['page_number']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('Page ${page['page_number']}'),
            subtitle: Text('${page['word_count']} words'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page['summary'],
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: page['summary']),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Summary copied')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImportantLinesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _importantLines.length,
      itemBuilder: (context, index) {
        final line = _importantLines[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getScoreColor(line['score']),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 16),
                  Text(
                    '${line['score']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              line['text'],
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            subtitle: Text('Position: ${line['position']}'),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: line['text']));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
          ),
        );
      },
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return Colors.red;
    if (score >= 5) return Colors.orange;
    return Colors.blue;
  }

  Widget _buildEntitiesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _entities.entries.map((entry) {
        if (entry.value.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: _getEntityIcon(entry.key),
            title: Text(
              _formatEntityType(entry.key),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${entry.value.length} found'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value.map((item) {
                    return Chip(
                      label: Text(item),
                      backgroundColor: _getEntityColor(entry.key),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Icon _getEntityIcon(String type) {
    switch (type) {
      case 'dates':
        return const Icon(Icons.calendar_today, color: Colors.green);
      case 'amounts':
        return const Icon(Icons.attach_money, color: Colors.orange);
      case 'definitions':
        return const Icon(Icons.book, color: Colors.blue);
      case 'emails':
        return const Icon(Icons.email, color: Colors.purple);
      case 'phone_numbers':
        return const Icon(Icons.phone, color: Colors.teal);
      case 'urls':
        return const Icon(Icons.link, color: Colors.indigo);
      default:
        return const Icon(Icons.label);
    }
  }

  Color _getEntityColor(String type) {
    switch (type) {
      case 'dates':
        return Colors.green.shade100;
      case 'amounts':
        return Colors.orange.shade100;
      case 'definitions':
        return Colors.blue.shade100;
      case 'emails':
        return Colors.purple.shade100;
      case 'phone_numbers':
        return Colors.teal.shade100;
      case 'urls':
        return Colors.indigo.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String _formatEntityType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildHighlightsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_highlights['definitions']?.isNotEmpty ?? false)
          _buildHighlightCategory(
            'Definitions',
            _highlights['definitions']!,
            Colors.blue,
            Icons.book,
          ),
        if (_highlights['dates']?.isNotEmpty ?? false)
          _buildHighlightCategory(
            'Dates',
            _highlights['dates']!,
            Colors.green,
            Icons.calendar_today,
          ),
        if (_highlights['amounts']?.isNotEmpty ?? false)
          _buildHighlightCategory(
            'Amounts',
            _highlights['amounts']!,
            Colors.yellow.shade700,
            Icons.attach_money,
          ),
      ],
    );
  }

  Widget _buildHighlightCategory(
    String title,
    List<Map<String, dynamic>> items,
    Color color,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${items.length} items'),
        children: items.map((item) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              item['text'],
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          );
        }).toList(),
      ),
    );
  }
}
