import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';  // Import Dio service
import 'color_upload_screen.dart';

class ColorsScreen extends ConsumerStatefulWidget {
  const ColorsScreen({super.key});

  @override
  ConsumerState<ColorsScreen> createState() => _ColorsScreenState();
}

class _ColorsScreenState extends ConsumerState<ColorsScreen> {
  final ApiService _apiService = ApiService();
  bool _sortAscending = true; // Track sort order
  int _refreshKey = 0; // Key to force rebuild of tabs

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
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Upload Excel',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ColorUploadScreen(),
                ),
              );
              // Reload data after returning from upload
              setState(() {
                _refreshKey++; // Force rebuild
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _refreshKey++; // Force rebuild
              });
            },
          ),
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
        key: ValueKey(_refreshKey),
        length: 9,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Colors.red,
              tabs: [
                Tab(text: 'Lacquer FIN'),
                Tab(text: 'Custom Color'),
                Tab(text: 'Metal FIN'),
                Tab(text: 'Wood FIN'),
                Tab(text: 'Effect Statistics'),
                Tab(text: 'Thien Hong'),
                Tab(text: 'Tam Viet'),
                Tab(text: 'Dinh Thieu'),
                Tab(text: 'MaiHome'),
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
                  _buildTab('thien_hong'),
                  _buildTab('tam_viet'),
                  _buildTab('dinh_thieu'),
                  _buildTab('mai_home'),
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
              dataRowMinHeight: 100,
              dataRowMaxHeight: 120,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFC00000).withValues(alpha: 0.1)),
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
                const DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'Supplier',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'Notes',
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
                
                // Determine if this is custom_color or supplier tables
                bool isCustomColor = item['ref_color'] != null || 
                                    item['code_items'] != null || 
                                    item['date_signed_off'] != null ||
                                    item['pro'] != null ||
                                    item['po'] != null;
                
                // Check if this is a supplier table (thien_hong, tam_viet, dinh_thieu, mai_home)
                bool isSupplierTable = tableName == 'thien_hong' || 
                                       tableName == 'tam_viet' || 
                                       tableName == 'dinh_thieu' || 
                                       tableName == 'mai_home';
                
                // For custom_color and supplier tables, status is 'status', for others it's also 'status'
                // For supplier tables, we display 'status' directly
                String statusValue = isSupplierTable ? (item['status'] ?? '') : 
                                     isCustomColor ? (item['pro'] ?? '') : 
                                     (item['status'] ?? '');
                
                // For supplier tables, supplier field doesn't exist (or could be derived from table name)
                // For custom_color use 'supplier', for others use sup_inchart
                String supplierValue = isSupplierTable ? _getSupplierName(tableName) : 
                                      isCustomColor ? (item['supplier'] ?? '') : 
                                      _convertSupInchart(item['sup_inchart']);
                String notes = item['notes']?.toString() ?? '';
                
                return DataRow(
                  cells: [
                    DataCell(Text(no.toString()), onTap: () => _showDetailDialog(context, item)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          displayName,
                          softWrap: true,
                        ),
                      ),
                      onTap: () => _showDetailDialog(context, item),
                    ),
                    DataCell(Text(statusValue), onTap: () => _showDetailDialog(context, item)),
                    DataCell(Text(supplierValue), onTap: () => _showDetailDialog(context, item)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          notes,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () => _showDetailDialog(context, item),
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
    
    // Determine which database/table this item is from based on available fields
    bool isCustomColor = item['ref_color'] != null || 
                        item['code_items'] != null || 
                        item['date_signed_off'] != null ||
                        item['pro'] != null ||
                        item['po'] != null;
    
    // Check if this is a supplier table entry (has order_no field)
    bool isSupplierTable = item['order_no'] != null;
    
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
              
              // Supplier tables specific fields (thien_hong, tam_viet, dinh_thieu, mai_home)
              if (isSupplierTable) ...[
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Ref Color', item['ref_color']),
                _buildDetailRow('ORDER NO.', item['order_no']),
                _buildDetailRow('Date Signed Off', item['date_signed_off']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('Pro', item['pro']),
                _buildDetailRow('PO', item['po']),
                _buildDetailRow('Notes', item['notes']),
              ] else if (isCustomColor) ...[
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Ref Color', item['ref_color']),
                _buildDetailRow('Code Items', item['code_items']),
                _buildDetailRow('Date Signed Off', item['date_signed_off']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('PRO', item['pro']),
                _buildDetailRow('PO', item['po']),
                _buildDetailRow('Supplier', item['supplier']),
                _buildDetailRow('Notes', item['notes']),
              ] else ...[
                // Other tables (Lacquer, Metal, Wood, Effect)
                _buildDetailRow('Collection', item['collection']),
                _buildDetailRow('Ref Tone Code', item['ref_tone_code']),
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Color Name', item['color_name']),
                _buildDetailRow('Swatch Name', item['swatch_name']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('Process', item['process']),
                _buildDetailRow('Qty', item['qty']),
                _buildDetailRow('Approved Day', item['approved_day']),
                _buildDetailRow('Sup-inchart', _convertSupInchart(item['sup_inchart'])),
                _buildDetailRow('Notes', item['notes']),
              ],
              
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

  // Get supplier name from table name
  String _getSupplierName(String tableName) {
    switch (tableName) {
      case 'thien_hong':
        return 'THIEN HONG';
      case 'tam_viet':
        return 'TAM VIET';
      case 'dinh_thieu':
        return 'DINH THIEU';
      case 'mai_home':
        return 'MAIHOME';
      default:
        return '';
    }
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Search Results (${results.length} items)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: 100,
                      dataRowMaxHeight: 120,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFC00000).withValues(alpha: 0.1)),
                      columns: const [
                        DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Color Item', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: results.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        
                        // Handle different field names for Effect Statistics table
                        String displayName = item['name'] ?? 
                                            item['color_name'] ?? 
                                            item['swatch_name'] ?? 
                                            'N/A';
                        
                        // Determine if this is custom_color
                        String? database = item['database'] ?? item['table_name'];
                        bool isCustomColor = database?.toLowerCase().contains('custom') ?? false;
                        
                        String statusValue = isCustomColor ? (item['pro'] ?? '') : (item['status'] ?? '');
                        String supplierValue = isCustomColor ? (item['supplier'] ?? '') : _convertSupInchart(item['sup_inchart']);
                        String notes = item['notes']?.toString() ?? '';
                        
                        return DataRow(
                          cells: [
                            DataCell(Text(index.toString()), onTap: () => _showDetailDialog(context, item)),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Text(
                                  displayName,
                                  softWrap: true,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(Text(statusValue), onTap: () => _showDetailDialog(context, item)),
                            DataCell(Text(supplierValue), onTap: () => _showDetailDialog(context, item)),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 300),
                                child: Text(
                                  notes,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
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
    // Determine which database/table this item is from
    String? database = item['database'] ?? item['table_name'];
    bool isCustomColor = database?.toLowerCase().contains('custom') ?? false;
    
    // Check if this is a supplier table entry (has order_no field)
    bool isSupplierTable = item['order_no'] != null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name'] ?? item['color_name'] ?? 'Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', item['id']),
              
              // Supplier tables specific fields (thien_hong, tam_viet, dinh_thieu, mai_home)
              if (isSupplierTable) ...[
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Ref Color', item['ref_color']),
                _buildDetailRow('ORDER NO.', item['order_no']),
                _buildDetailRow('Date Signed Off', item['date_signed_off']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('Pro', item['pro']),
                _buildDetailRow('PO', item['po']),
                _buildDetailRow('Notes', item['notes']),
              ] else if (isCustomColor) ...[
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Ref Color', item['ref_color']),
                _buildDetailRow('Code Items', item['code_items']),
                _buildDetailRow('Date Signed Off', item['date_signed_off']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('PRO', item['pro']),
                _buildDetailRow('PO', item['po']),
                _buildDetailRow('Supplier', item['supplier']),
                _buildDetailRow('Notes', item['notes']),
              ] else ...[
                // Other tables (Lacquer, Metal, Wood, Effect)
                _buildDetailRow('Collection', item['collection']),
                _buildDetailRow('Ref Tone Code', item['ref_tone_code']),
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Color Name', item['color_name']),
                _buildDetailRow('Swatch Name', item['swatch_name']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('Process', item['process']),
                _buildDetailRow('Qty', item['qty']),
                _buildDetailRow('Approved Day', item['approved_day']),
                _buildDetailRow('Sup-inchart', _convertSupInchart(item['sup_inchart'])),
                _buildDetailRow('Notes', item['notes']),
              ],
              
              _buildDetailRow('Database', database),
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