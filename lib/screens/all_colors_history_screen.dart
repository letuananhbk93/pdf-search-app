import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AllColorsHistoryScreen extends StatefulWidget {
  const AllColorsHistoryScreen({super.key});

  @override
  State<AllColorsHistoryScreen> createState() => _AllColorsHistoryScreenState();
}

class _AllColorsHistoryScreenState extends State<AllColorsHistoryScreen> {
  static const _pageSize = 50;

  static const List<Map<String, String>> _tables = [
    {'value': '', 'label': 'All Tables'},
    {'value': 'lacquer_fin', 'label': 'Lacquer FIN'},
    {'value': 'custom_color', 'label': 'Custom Color'},
    {'value': 'metal_fin', 'label': 'Metal FIN'},
    {'value': 'wood_fin', 'label': 'Wood FIN'},
    {'value': 'effect_color_swatch_statistics', 'label': 'Effect Color'},
    {'value': 'thien_hong', 'label': 'Thiên Hồng'},
    {'value': 'tam_viet', 'label': 'Tâm Việt'},
    {'value': 'dinh_thieu', 'label': 'Đinh Thiệu'},
    {'value': 'mai_home', 'label': 'Mai Home'},
  ];

  static const List<Map<String, String>> _actions = [
    {'value': '', 'label': 'All Actions'},
    {'value': 'INSERT', 'label': 'INSERT'},
    {'value': 'UPDATE', 'label': 'UPDATE'},
    {'value': 'DELETE', 'label': 'DELETE'},
  ];

  final ApiService _apiService = ApiService();
  final TextEditingController _userSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  // Filter variables
  String _selectedTable = '';
  String _selectedAction = '';
  String _searchUser = '';

  // Pagination
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Identifies the latest request so stale responses are ignored
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Load the next page shortly before the user reaches the bottom
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadHistory(loadMore: true);
    }
  }

  Future<void> _loadHistory({bool loadMore = false}) async {
    if (loadMore && (_isLoadingMore || !_hasMore)) return;

    final requestId = ++_requestId;

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await _apiService.getAllColorsHistory(
        limit: _pageSize,
        offset: loadMore ? _historyData.length : 0,
        tableFilter: _selectedTable.isNotEmpty ? _selectedTable : null,
        actionFilter: _selectedAction.isNotEmpty ? _selectedAction : null,
        changedByFilter: _searchUser.isNotEmpty ? _searchUser : null,
      );

      // Drop responses from superseded requests or after the screen is closed
      if (!mounted || requestId != _requestId) return;

      final history = List<Map<String, dynamic>>.from(response['history'] ?? []);
      setState(() {
        if (loadMore) {
          _historyData.addAll(history);
          _isLoadingMore = false;
        } else {
          _historyData = history;
          _isLoading = false;
        }
        _hasMore = response['has_more'] ?? false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        if (loadMore) {
          _isLoadingMore = false;
        } else {
          _isLoading = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    }
  }

  void _applyUserSearch(String value) {
    _searchUser = value.trim();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Colors Change History'),
        backgroundColor: const Color(0xFFC00000),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadHistory(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Table Filter Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedTable,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Table',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _tables.map((table) => DropdownMenuItem(
                    value: table['value'],
                    child: Text(table['label']!),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedTable = value ?? '');
                    _loadHistory();
                  },
                ),
                const SizedBox(height: 12),

                // Action Filter and User Search Row
                Row(
                  children: [
                    // Action Filter Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedAction,
                        decoration: const InputDecoration(
                          labelText: 'Action',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _actions.map((action) => DropdownMenuItem(
                          value: action['value'],
                          child: Text(action['label']!),
                        )).toList(),
                        onChanged: (value) {
                          setState(() => _selectedAction = value ?? '');
                          _loadHistory();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // User Search Field
                    Expanded(
                      child: TextField(
                        controller: _userSearchController,
                        decoration: InputDecoration(
                          labelText: 'Search User',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => _applyUserSearch(_userSearchController.text),
                          ),
                        ),
                        onSubmitted: _applyUserSearch,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Loading bar or results count
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Showing ${_historyData.length} records${_hasMore ? ' (more available)' : ''}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // History list
          Expanded(
            child: _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoading && _historyData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyData.isEmpty) {
      return const Center(
        child: Text(
          'No history found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHistory(),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _historyData.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _historyData.length) {
            // Load more button
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoadingMore
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () => _loadHistory(loadMore: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC00000),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Load More'),
                  ),
            );
          }

          final historyItem = _historyData[index];
          return _buildHistoryCard(historyItem);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> historyItem) {
    final changedAt = _formatChangedAt(historyItem['changed_at']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text('${historyItem['table_name']?.replaceAll('_', ' ').toUpperCase() ?? 'Unknown'} - ${historyItem['color_name'] ?? historyItem['record_name'] ?? 'Unknown'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Action: ${historyItem['action']} by ${historyItem['changed_by'] ?? 'Unknown'}'),
            if (changedAt != null)
              Text(changedAt),
            if (historyItem['action'] == 'UPDATE' && historyItem['changes_count'] != null)
              Text(
                '${historyItem['changes_count']} field(s) changed',
                style: TextStyle(color: Colors.orange[700], fontSize: 12),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getActionColor(historyItem['action']),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            historyItem['action'] ?? 'UNKNOWN',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        onTap: () => _showHistoryDetails(historyItem),
      ),
    );
  }

  Color _getActionColor(String? action) {
    switch (action) {
      case 'INSERT': return Colors.green;
      case 'UPDATE': return Colors.orange;
      case 'DELETE': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showHistoryDetails(Map<String, dynamic> item) {
    final oldData = item['old_data'];
    final newData = item['new_data'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item['table_name']?.replaceAll('_', ' ').toUpperCase() ?? 'Unknown'} - Change Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Color Name', item['color_name'] ?? item['record_name']),
              _buildDetailRow('Action', item['action']),
              _buildDetailRow('Changed By', item['changed_by']),
              _buildDetailRow('Changed At', _formatChangedAt(item['changed_at'])),

              if (oldData is Map<String, dynamic> && newData is Map<String, dynamic>) ...[
                const SizedBox(height: 16),
                const Text(
                  'Changes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildChangesComparison(oldData, newData),
              ] else if (newData is Map<String, dynamic>) ...[
                const SizedBox(height: 16),
                const Text(
                  'New Data:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildNewDataDisplay(newData),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String? _formatChangedAt(dynamic value) {
    if (value == null) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    // Unparseable values are shown as-is
    if (parsed == null) return value.toString();

    final local = parsed.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value.toString(), style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildChangesComparison(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    List<Widget> changes = [];

    final keys = {...oldData.keys, ...newData.keys};

    for (final key in keys) {
      String oldValue = oldData[key]?.toString() ?? 'null';
      String newValueStr = newData[key]?.toString() ?? 'null';

      if (oldValue != newValueStr) {
        changes.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'Old: $oldValue',
                          style: TextStyle(color: Colors.red[800], fontSize: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green, width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'New: $newValueStr',
                          style: TextStyle(color: Colors.green[800], fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    if (changes.isEmpty) {
      return const Text(
        'No field changes',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    return Column(children: changes);
  }

  Widget _buildNewDataDisplay(Map<String, dynamic> newData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: newData.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: const TextStyle(fontSize: 11),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
