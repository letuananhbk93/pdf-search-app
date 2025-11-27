import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';  // Import Dio service

class ColorsScreen extends ConsumerStatefulWidget {
  const ColorsScreen({super.key});

  @override
  ConsumerState<ColorsScreen> createState() => _ColorsScreenState();
}

class _ColorsScreenState extends ConsumerState<ColorsScreen> {
  final ApiService _apiService = ApiService();
  bool _sortAscending = true; // Track sort order

  // Convert sup_inchart acronyms to full names
  String _convertSupInchart(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    
    // Map of acronyms to full names
    const Map<String, String> acronymMap = {
      'TH': 'THIEN HONG',
      'TV': 'TAM VIET',
      'DT': 'DINH THIEU',
      'MH': 'MAIHOME',
    };
    
    // Split by comma and space, trim each part
    List<String> parts = value.split(',').map((e) => e.trim()).toList();
    
    // Convert each acronym to full name
    List<String> fullNames = parts.map((acronym) {
      return acronymMap[acronym.toUpperCase()] ?? acronym;
    }).toList();
    
    // Join with comma and space
    return fullNames.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'COLOR TABLES',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),  // Bordeaux theme
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ColorSearchDelegate(),
              );
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Colors.red,
              tabs: [
                Tab(text: 'Lacquer FIN'),
                Tab(text: 'Custom Color'),
                Tab(text: 'Metal FIN'),
                Tab(text: 'Wood FIN'),
                Tab(text: 'Effect Statistics'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTab('lacquer_fin'),
                  _buildTab('custom_color'),
                  _buildTab('metal_fin'),
                  _buildTab('wood_fin'),
                  _buildTab('effect_color_swatch_statistics'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String tableName) {
    return FutureBuilder<List<dynamic>>(
      future: _apiService.fetchColorTable(tableName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading $tableName...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final data = snapshot.data ?? [];
        
        if (data.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No data available', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        // Filter out items where name field is null
        // For Effect Statistics table, check 'color_name', otherwise check 'name'
        final filteredData = data.where((item) {
          if (tableName == 'effect_color_swatch_statistics') {
            return item['color_name'] != null;
          } else {
            return item['name'] != null;
          }
        }).toList();
        
        if (filteredData.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No data available', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        // Create a sorted list with indices
        List<MapEntry<int, Map<String, dynamic>>> indexedData = [];
        for (int i = 0; i < filteredData.length; i++) {
          indexedData.add(MapEntry(i + 1, filteredData[i]));
        }
        
        // Sort based on current sort order
        if (!_sortAscending) {
          indexedData = indexedData.reversed.toList();
        }
        
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: 0,
              sortAscending: _sortAscending,
              dataRowMinHeight: 90,
              dataRowMaxHeight: 90,
              columns: [
                DataColumn(
                  label: const Text(
                    'No.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onSort: (columnIndex, ascending) {
                    setState(() {
                      _sortAscending = !_sortAscending;
                    });
                  },
                ),
                const DataColumn(
                  label: Text(
                    'Color Item',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: indexedData.map((entry) {
                final no = entry.key;
                final item = entry.value;
                
                // Handle different field names for Effect Statistics table
                String displayName = item['name'] ?? 
                                    item['color_name'] ?? 
                                    item['swatch_name'] ?? 
                                    'N/A';
                
                // Build color item display with status and sup-inchart
                String colorItemText = '$displayName\n'
                    'Status: ${item['status'] ?? 'N/A'}\n'
                    'Sup-inchart: ${_convertSupInchart(item['sup_inchart'])}';
                
                return DataRow(
                  cells: [
                    DataCell(
                      Text(no.toString()),
                    ),
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Text(
                          colorItemText,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () {
                        _showDetailDialog(context, item);
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> item) {
    // Handle different field names for Effect Statistics table
    String displayName = item['name'] ?? 
                        item['color_name'] ?? 
                        item['swatch_name'] ?? 
                        'Details';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', item['id']),
              _buildDetailRow('Collection', item['collection']),
              _buildDetailRow('Ref Tone Code', item['ref_tone_code']),
              _buildDetailRow('Name', item['name']),
              _buildDetailRow('Color Name', item['color_name']),
              _buildDetailRow('Name', item['color_name']),
              _buildDetailRow('Swatch Name', item['swatch_name']),
              _buildDetailRow('Status', item['status']),
              _buildDetailRow('Process', item['process']),
              _buildDetailRow('Qty', item['qty']),
              _buildDetailRow('Approved Day', item['approved_day']),
              _buildDetailRow('Sup-inchart', _convertSupInchart(item['sup_inchart'])),
              _buildDetailRow('Notes', item['notes']),
              _buildDetailRow('Database', item['database']),
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

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }
}

// Search delegate for searching across all color databases
class ColorSearchDelegate extends SearchDelegate {
  final ApiService _apiService = ApiService();

  // Convert sup_inchart acronyms to full names
  String _convertSupInchart(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    
    // Map of acronyms to full names
    const Map<String, String> acronymMap = {
      'TH': 'THIEN HONG',
      'TV': 'TAM VIET',
      'DT': 'DINH THIEU',
      'MH': 'MAIHOME',
    };
    
    // Split by comma and space, trim each part
    List<String> parts = value.split(',').map((e) => e.trim()).toList();
    
    // Convert each acronym to full name
    List<String> fullNames = parts.map((acronym) {
      return acronymMap[acronym.toUpperCase()] ?? acronym;
    }).toList();
    
    // Join with comma and space
    return fullNames.join(', ');
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Enter a search term'),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: _apiService.searchColors(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (snapshot.hasData) {
          final results = snapshot.data!;

          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "$query"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              
              // Debug: Print all fields in the item
              print('Search result item $index fields: ${item.keys.toList()}');
              print('Search result item $index data: $item');
              
              // Handle different field names for Effect Statistics table
              String displayName = item['name'] ?? 
                                  item['color_name'] ?? 
                                  item['swatch_name'] ?? 
                                  'N/A';
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Status: ${item['status'] ?? 'N/A'}'),
                      Text('Sup-inchart: ${_convertSupInchart(item['sup_inchart'] ?? item['supInchart'] ?? item['supplier'])}'),
                      if (item['database'] != null || item['table_name'] != null)
                        Text(
                          'Database: ${item['database'] ?? item['table_name']}',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showDetailDialog(context, item);
                  },
                ),
              );
            },
          );
        }

        return const Center(child: Text('No data available'));
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> item) {
    // Debug: Print the item data
    print('Detail dialog item: $item');
    print('sup_inchart value: ${item['sup_inchart']}');
    print('Converted: ${_convertSupInchart(item['sup_inchart'])}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name'] ?? 'Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', item['id']),
              _buildDetailRow('Collection', item['collection']),
              _buildDetailRow('Ref Tone Code', item['ref_tone_code']),
              _buildDetailRow('Name', item['name']),
              _buildDetailRow('Status', item['status']),
              _buildDetailRow('Process', item['process']),
              _buildDetailRow('Qty', item['qty']),
              _buildDetailRow('Approved Day', item['approved_day']),
              _buildDetailRow('Sup-inchart', _convertSupInchart(item['sup_inchart'])),
              _buildDetailRow('Notes', item['notes']),
              _buildDetailRow('Database', item['database'] ?? item['table_name']),
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

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }
}