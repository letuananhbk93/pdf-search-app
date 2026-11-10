import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';  // Import Dio service
import 'color_upload_screen.dart';
import 'edit_color_screen.dart';
import 'all_colors_history_screen.dart';

class ColorsScreen extends ConsumerStatefulWidget {
  const ColorsScreen({super.key});

  @override
  ConsumerState<ColorsScreen> createState() => _ColorsScreenState();
}

class _ColorsScreenState extends ConsumerState<ColorsScreen> {
  // Same order as the tabs below
  static const List<String> _tableNames = [
    'lacquer_fin',
    'custom_color',
    'metal_fin',
    'wood_fin',
    'effect_color_swatch_statistics',
    'thien_hong',
    'tam_viet',
    'dinh_thieu',
    'mai_home',
  ];

  final ApiService _apiService = ApiService();
  bool _sortAscending = true; // Track sort order
  int _sortColumnIndex = 0; // Track which column is being sorted (0 = No., 5 = PO)
  // One request per table, reused on every rebuild (sorting etc.) instead of refetching
  final Map<String, Future<List<dynamic>>> _tableFutures = {};
  String? _lastUpdateDate; // Track last update date

  @override
  void initState() {
    super.initState();
    _loadAllTables();
    _fetchLastUpdateDate();
  }

  // Start (or restart) the request for one table
  void _loadTable(String tableName) {
    _tableFutures[tableName] = _apiService.fetchColorTable(tableName);
  }

  void _loadAllTables() {
    for (final tableName in _tableNames) {
      _loadTable(tableName);
    }
  }

  // Fetch last update date from API
  Future<void> _fetchLastUpdateDate() async {
    try {
      // You'll need to add this method to your ApiService
      final updateInfo = await _apiService.getLastUpdateInfo('colors');
      if (!mounted) return;
      setState(() {
        _lastUpdateDate = updateInfo['last_update'] ?? 'Unknown';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastUpdateDate = 'Unknown';
      });
    }
  }

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
          // Last update date display
          if (_lastUpdateDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Center(
                child: Text(
                  'Updated: $_lastUpdateDate',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Menu',
            onSelected: (String choice) {
              switch (choice) {
                case 'history':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllColorsHistoryScreen(),
                    ),
                  );
                  break;
                case 'upload':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ColorUploadScreen(),
                    ),
                  ).then((_) {
                    // Reload data and update date after returning from upload
                    setState(_loadAllTables);
                    _fetchLastUpdateDate(); // Refresh the update date
                  });
                  break;
                case 'refresh':
                  setState(_loadAllTables);
                  _fetchLastUpdateDate(); // Also refresh the update date
                  break;
                case 'search':
                  showSearch(
                    context: context,
                    delegate: ColorSearchDelegate(
                      onChanged: (tableName) => setState(() => _loadTable(tableName)),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('View All History'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Upload Excel'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Search'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: DefaultTabController(
        length: _tableNames.length,
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
                children: _tableNames.map(_buildTab).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String tableName) {
    return FutureBuilder<List<dynamic>>(
      future: _tableFutures[tableName],
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
                    onPressed: () => setState(() => _loadTable(tableName)),
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
        
        // Sort based on current sort column and order
        if (_sortColumnIndex == 0) {
          // Sort by No. (original order)
          if (!_sortAscending) {
            indexedData = indexedData.reversed.toList();
          }
        } else if (_sortColumnIndex == 5) {
          // Sort by PO column by year first, then by number
          indexedData.sort((a, b) {
            // Extract PO values
            final aItem = a.value;
            final bItem = b.value;
            
            bool aIsCustomOrSupplier = aItem['ref_color'] != null || 
                                      aItem['code_items'] != null || 
                                      aItem['date_signed_off'] != null ||
                                      aItem['pro'] != null ||
                                      aItem['po'] != null;
            
            bool bIsCustomOrSupplier = bItem['ref_color'] != null || 
                                      bItem['code_items'] != null || 
                                      bItem['date_signed_off'] != null ||
                                      bItem['pro'] != null ||
                                      bItem['po'] != null;
            
            String aPoValue = aIsCustomOrSupplier ? (aItem['po']?.toString() ?? '') : '';
            String bPoValue = bIsCustomOrSupplier ? (bItem['po']?.toString() ?? '') : '';
            
            // Handle empty PO values - always put them at the bottom
            bool aIsEmpty = aPoValue.isEmpty;
            bool bIsEmpty = bPoValue.isEmpty;
            
            if (aIsEmpty && bIsEmpty) {
              return 0; // Both empty, keep original order
            } else if (aIsEmpty) {
              return 1; // A is empty, put it after B
            } else if (bIsEmpty) {
              return -1; // B is empty, put it after A
            }
            
            // Parse PO pattern "POx-yy"
            final poPattern = RegExp(r'^PO(\d+)-(\d+)$', caseSensitive: false);
            final aMatch = poPattern.firstMatch(aPoValue);
            final bMatch = poPattern.firstMatch(bPoValue);
            
            int result = 0;
            
            if (aMatch != null && bMatch != null) {
              // Both match the POx-yy pattern
              int aNumber = int.parse(aMatch.group(1)!);
              int aYear = int.parse(aMatch.group(2)!);
              int bNumber = int.parse(bMatch.group(1)!);
              int bYear = int.parse(bMatch.group(2)!);
              
              // Sort by year first (descending), then by number (ascending)
              if (aYear != bYear) {
                result = bYear.compareTo(aYear); // Descending year order
              } else {
                result = aNumber.compareTo(bNumber); // Ascending number order
              }
            } else {
              // Fallback to alphabetical comparison
              result = aPoValue.toLowerCase().compareTo(bPoValue.toLowerCase());
            }
            
            return _sortAscending ? result : -result;
          });
        }
        
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
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
                      _sortColumnIndex = 0; // No. column index
                      _sortAscending = ascending;
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
                DataColumn(
                  label: const Text(
                    'PO',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onSort: (columnIndex, ascending) {
                    setState(() {
                      _sortColumnIndex = 5; // PO column index
                      _sortAscending = ascending;
                    });
                  },
                ),
                const DataColumn(
                  label: Text(
                    'Notes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'Actions',
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
                
                // Extract PO value for tables that have it
                String poValue = (isCustomColor || isSupplierTable) ? (item['po']?.toString() ?? '') : '';
                
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
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          poValue,
                          softWrap: true,
                        ),
                      ),
                      onTap: () => _showDetailDialog(context, item),
                    ),
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
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _navigateToEditScreen(context, item, tableName),
                        tooltip: 'Edit',
                      ),
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
        title: SelectableText(displayName),
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
                _buildDetailRow('Product Name', item['product_name']),
                _buildDetailRow('Notes', item['notes']),
              ] else if (isCustomColor) ...[
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Ref Color', item['ref_color']),
                _buildDetailRow('Code Items', item['code_items']),
                _buildDetailRow('Date Signed Off', item['date_signed_off']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('PRO', item['pro']),
                _buildDetailRow('PO', item['po']),
                _buildDetailRow('Product Name', item['product_name']),
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
          Expanded(child: SelectableText(value.toString())),
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

  // Navigate to edit screen
  void _navigateToEditScreen(BuildContext context, Map<String, dynamic> colorItem, String tableName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditColorScreen(
          colorItem: colorItem,
          tableName: tableName,
        ),
      ),
    );
    
    // If changes were made, reload that table
    if (result == true) {
      setState(() => _loadTable(tableName));
    }
  }
}

// Search delegate for searching across all color databases
class ColorSearchDelegate extends SearchDelegate {
  ColorSearchDelegate({this.onChanged});

  final ApiService _apiService = ApiService();
  // Called with the table name after an item is edited from the results
  final void Function(String tableName)? onChanged;
  // Results per query, so suggestions and results share one request and typing back shows cached results
  final Map<String, Future<List<dynamic>>> _searchCache = {};

  // Wait briefly after typing so only a pause in typing sends a request
  Future<List<dynamic>> _searchFor(String searchText) {
    return _searchCache.putIfAbsent(searchText, () async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (searchText != query) {
        // User kept typing, this request is no longer needed
        _searchCache.remove(searchText);
        return <dynamic>[];
      }
      try {
        return await _apiService.searchColors(searchText);
      } catch (e) {
        _searchCache.remove(searchText);
        rethrow;
      }
    });
  }

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
      future: _searchFor(query),
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
                      dataRowMaxHeight: 120,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFC00000).withValues(alpha: 0.1)),
                      columns: const [
                        DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Color Item', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: results.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;

                        // Determine which database this item is from
                        String? database = item['database'] ?? item['table_name'];
                        bool isLogoColor = database == 'logo_color';
                        bool isCustomColor = database?.toLowerCase().contains('custom') ?? false;

                        // Logo records have main_color -> logo_color shape
                        String displayName = isLogoColor
                            ? (item['main_color'] ?? item['name'] ?? 'N/A').toString()
                            : (item['name'] ??
                                item['color_name'] ??
                                item['swatch_name'] ??
                                'N/A').toString();

                        String statusValue = isLogoColor
                            ? (item['logo_color'] ?? '').toString()
                            : (isCustomColor ? (item['pro'] ?? '') : (item['status'] ?? '')).toString();
                        String supplierValue = isLogoColor
                            ? 'LOGO / LAMP'
                            : (isCustomColor ? (item['supplier'] ?? '') : _convertSupInchart(item['sup_inchart'])).toString();
                        String notes = isLogoColor ? '' : (item['notes']?.toString() ?? '');

                        // Determine the table name for edit navigation
                        String tableName = database ?? 'lacquer_fin';
                        
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
                            DataCell(
                              IconButton(
                                icon: Icon(
                                  isLogoColor ? Icons.branding_watermark : Icons.edit,
                                  color: isLogoColor ? Colors.grey : Colors.blue,
                                ),
                                onPressed: isLogoColor
                                    ? null
                                    : () => _navigateToEditScreen(context, item, tableName),
                                tooltip: isLogoColor ? 'Logo mapping (read-only)' : 'Edit',
                              ),
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
    bool isLogoColor = database == 'logo_color';
    bool isCustomColor = database?.toLowerCase().contains('custom') ?? false;

    // Logo records: main_color -> logo_color shape (no status/supplier/product_name)
    if (isLogoColor) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: SelectableText((item['main_color'] ?? item['name'] ?? 'Details').toString()),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('STT', item['stt']),
                _buildDetailRow('Main Color (TLC COLOR)', item['main_color'] ?? item['name']),
                _buildDetailRow('Logo Color (LOGO COLOR)', item['logo_color']),
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
      return;
    }

    // Check if this is a supplier table entry (has order_no field)
    bool isSupplierTable = item['order_no'] != null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: SelectableText(item['name'] ?? item['color_name'] ?? 'Details'),
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
                _buildDetailRow('Product Name', item['product_name']),
                _buildDetailRow('Notes', item['notes']),
              ] else if (isCustomColor) ...[
                _buildDetailRow('Name', item['name']),
                _buildDetailRow('Ref Color', item['ref_color']),
                _buildDetailRow('Code Items', item['code_items']),
                _buildDetailRow('Date Signed Off', item['date_signed_off']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('PRO', item['pro']),
                _buildDetailRow('PO', item['po']),
                _buildDetailRow('Product Name', item['product_name']),
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
          Expanded(child: SelectableText(value.toString())),
        ],
      ),
    );
  }

  // Navigate to edit screen (for search delegate)
  void _navigateToEditScreen(BuildContext context, Map<String, dynamic> colorItem, String tableName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditColorScreen(
          colorItem: colorItem,
          tableName: tableName,
        ),
      ),
    );
    
    // If changes were made, let the main screen reload this table
    if (result == true) {
      onChanged?.call(tableName);
    }
  }
}