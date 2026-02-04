import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ColorHistoryScreen extends StatefulWidget {
  final int colorId;
  final String tableName;
  final String colorName;

  const ColorHistoryScreen({
    super.key,
    required this.colorId,
    required this.tableName,
    required this.colorName,
  });

  @override
  State<ColorHistoryScreen> createState() => _ColorHistoryScreenState();
}

class _ColorHistoryScreenState extends State<ColorHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    try {
      final history = await _apiService.getColorHistory(
        widget.tableName,
        widget.colorId,
      );
      
      setState(() {
        _historyData = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History: ${widget.colorName}'),
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _historyData.isEmpty
          ? const Center(
              child: Text(
                'No history found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _historyData.length,
              itemBuilder: (context, index) {
                final historyItem = _historyData[index];
                return _buildHistoryCard(historyItem);
              },
            ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> historyItem) {
    DateTime? changedAt = historyItem['changed_at'] != null 
      ? DateTime.parse(historyItem['changed_at'])
      : null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with action and timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
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
                Text(
                  changedAt != null 
                    ? '${changedAt.day}/${changedAt.month}/${changedAt.year} ${changedAt.hour}:${changedAt.minute.toString().padLeft(2, '0')}'
                    : 'Unknown time',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Changed by
            Text(
              'Changed by: ${historyItem['changed_by'] ?? 'Unknown'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Changes details
            if (historyItem['old_data'] != null && historyItem['new_data'] != null)
              _buildChangesComparison(historyItem['old_data'], historyItem['new_data'])
            else if (historyItem['new_data'] != null)
              _buildNewDataDisplay(historyItem['new_data']),
          ],
        ),
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

  Widget _buildChangesComparison(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    List<Widget> changes = [];
    
    newData.forEach((key, newValue) {
      String oldValue = oldData[key]?.toString() ?? 'null';
      String newValueStr = newValue?.toString() ?? 'null';
      
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Old: $oldValue',
                          style: TextStyle(color: Colors.red[800], fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'New: $newValueStr',
                          style: TextStyle(color: Colors.green[800], fontSize: 12),
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
    });
    
    return Column(children: changes);
  }

  Widget _buildNewDataDisplay(Map<String, dynamic> newData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: newData.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }
}
