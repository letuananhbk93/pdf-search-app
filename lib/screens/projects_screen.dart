// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'process_upload_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  List<String> _projects = [];
  String? _selectedProject;
  Map<String, List<dynamic>>? _projectData;
  bool _isLoadingProjects = true;
  bool _isLoadingData = false;
  String? _error;
  
  TabController? _tabController;
  List<String> _tabNames = [];
  
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String _formatTableName(String tableKey, String projectName) {
    // Table names from backend don't have project prefix
    // Just replace underscores with spaces and convert to uppercase
    // "anh_thiep" -> "ANH THIEP"
    // "thien_hong_may_bay" -> "THIEN HONG MAY BAY"
    return tableKey.replaceAll('_', ' ').toUpperCase();
  }

  String _cleanColourText(String? colour) {
    if (colour == null || colour.isEmpty) return '';
    
    // Replace all newlines (one or multiple) with a single space
    // Also replace multiple spaces with single space
    return colour
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _error = null;
    });

    try {
      final projects = await _apiService.fetchProjects();
      setState(() {
        _projects = projects;
        _isLoadingProjects = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadProjectData(String projectName) async {
    setState(() {
      _isLoadingData = true;
      _error = null;
      _projectData = null;
    });

    try {
      final data = await _apiService.fetchProjectData(projectName);
      
      print('=== DEBUG: Project Data Keys ===');
      print('Project Name: $projectName');
      print('Data keys: ${data.keys.toList()}');
      
      // Generate tab names from database keys
      final tableKeys = data.keys.toList();
      final newTabNames = tableKeys.map((key) {
        final formatted = _formatTableName(key, projectName);
        print('Key: "$key" -> Formatted: "$formatted"');
        return formatted;
      }).toList();
      
      print('Final tab names: $newTabNames');
      
      // Only recreate tab controller if length changed or it doesn't exist
      if (_tabController == null || _tabController!.length != newTabNames.length) {
        _tabController?.dispose();
        _tabController = TabController(length: newTabNames.length, vsync: this);
      }
      
      setState(() {
        _tabNames = newTabNames;
        _projectData = data;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingData = false;
      });
    }
  }

  void _onProjectSelected(String? projectName) {
    if (projectName != null && projectName != _selectedProject) {
      setState(() {
        _selectedProject = projectName;
      });
      _loadProjectData(projectName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PROCESS',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Upload Excel',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProcessUploadScreen(),
                ),
              );
              // Reload data after returning from upload
              if (_selectedProject != null) {
                _loadProjectData(_selectedProject!);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              if (_selectedProject != null) {
                _loadProjectData(_selectedProject!);
              } else {
                _loadProjects();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ProcessSearchDelegate(),
              );
            },
          ),
        ],
        bottom: _selectedProject != null && _tabController != null
            ? TabBar(
                controller: _tabController!,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: _tabNames.map((name) => Tab(text: name)).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Project selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Select Project:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isLoadingProjects
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButton<String>(
                          value: _selectedProject,
                          hint: const Text('Choose a project'),
                          isExpanded: true,
                          items: _projects.map((project) {
                            return DropdownMenuItem<String>(
                              value: project,
                              child: Text(project),
                            );
                          }).toList(),
                          onChanged: _onProjectSelected,
                        ),
                ),
              ],
            ),
          ),
          
          // Content area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedProject != null
                  ? () => _loadProjectData(_selectedProject!)
                  : _loadProjects,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_selectedProject == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Please select a project',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isLoadingData) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading project data...'),
          ],
        ),
      );
    }

    if (_projectData == null || _tabController == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedProject != null) {
          await _loadProjectData(_selectedProject!);
        }
      },
      child: TabBarView(
        controller: _tabController!,
        children: _projectData!.keys.map((tableKey) {
          final displayName = _formatTableName(tableKey, _selectedProject!);
          final data = _projectData![tableKey] ?? [];
          
          return _buildTableView(displayName, data);
        }).toList(),
      ),
    );
  }

  Widget _buildTableView(String tableName, List<dynamic> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No data in $tableName',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort data based on current sort column
    List<dynamic> sortedData = List.from(data);
    if (_sortColumnIndex != null) {
      sortedData.sort((a, b) {
        int comparison = 0;
        
        switch (_sortColumnIndex) {
          case 0: // Product
            comparison = (a['product']?.toString() ?? '').compareTo(b['product']?.toString() ?? '');
            break;
          case 1: // Order
            final aShipTo = a['ship_to']?.toString() ?? '';
            final aOrderNo = a['order_no']?.toString() ?? '';
            final aOrder = (aShipTo.isNotEmpty && aOrderNo.isNotEmpty) ? '$aShipTo-$aOrderNo' : '$aShipTo$aOrderNo';
            
            final bShipTo = b['ship_to']?.toString() ?? '';
            final bOrderNo = b['order_no']?.toString() ?? '';
            final bOrder = (bShipTo.isNotEmpty && bOrderNo.isNotEmpty) ? '$bShipTo-$bOrderNo' : '$bShipTo$bOrderNo';
            
            // Check if contains STOCK
            bool aHasStock = aOrder.toUpperCase().contains('STOCK');
            bool bHasStock = bOrder.toUpperCase().contains('STOCK');
            
            if (aHasStock && !bHasStock) {
              comparison = 1; // b comes first (numbers before STOCK)
            } else if (!aHasStock && bHasStock) {
              comparison = -1; // a comes first (numbers before STOCK)
            } else {
              comparison = aOrder.compareTo(bOrder);
            }
            break;
          case 2: // Colour
            comparison = _cleanColourText(a['colour']?.toString()).compareTo(_cleanColourText(b['colour']?.toString()));
            break;
          case 3: // Carcass QC
            final aValue = a['carcass_qc_day']?.toString() ?? '';
            final bValue = b['carcass_qc_day']?.toString() ?? '';
            
            final aShipTo = a['ship_to']?.toString() ?? '';
            final aOrderNo = a['order_no']?.toString() ?? '';
            final aOrder = (aShipTo.isNotEmpty && aOrderNo.isNotEmpty) ? '$aShipTo-$aOrderNo' : '$aShipTo$aOrderNo';
            
            final bShipTo = b['ship_to']?.toString() ?? '';
            final bOrderNo = b['order_no']?.toString() ?? '';
            final bOrder = (bShipTo.isNotEmpty && bOrderNo.isNotEmpty) ? '$bShipTo-$bOrderNo' : '$bShipTo$bOrderNo';
            
            bool aHasShowroom = aOrder.toUpperCase().contains('SHOWROOM');
            bool aHasStock = aOrder.toUpperCase().contains('STOCK');
            bool bHasShowroom = bOrder.toUpperCase().contains('SHOWROOM');
            bool bHasStock = bOrder.toUpperCase().contains('STOCK');
            
            // Helper function to get order priority (lower number = higher priority)
            int getOrderPriority(bool hasShowroom, bool hasStock) {
              if (!hasShowroom && !hasStock) return 1; // Numeric order (highest priority)
              if (hasShowroom) return 2; // SHOWROOM
              if (hasStock) return 3; // STOCK (lowest priority)
              return 4;
            }
            
            if (aValue.isEmpty && bValue.isEmpty) {
              // Both blank - compare by order type
              int aPriority = getOrderPriority(aHasShowroom, aHasStock);
              int bPriority = getOrderPriority(bHasShowroom, bHasStock);
              comparison = aPriority.compareTo(bPriority);
            } else if (aValue.isEmpty && bValue.isNotEmpty) {
              // a is blank, b has value - a comes first
              comparison = -1;
            } else if (aValue.isNotEmpty && bValue.isEmpty) {
              // a has value, b is blank - b comes first
              comparison = 1;
            } else {
              // Both have values - compare by order type first, then by value
              int aPriority = getOrderPriority(aHasShowroom, aHasStock);
              int bPriority = getOrderPriority(bHasShowroom, bHasStock);
              
              if (aPriority != bPriority) {
                comparison = aPriority.compareTo(bPriority);
              } else {
                comparison = aValue.compareTo(bValue);
              }
            }
            break;
          case 4: // Final QC
            final aValue = a['final_qc_date']?.toString() ?? '';
            final bValue = b['final_qc_date']?.toString() ?? '';
            
            final aShipTo = a['ship_to']?.toString() ?? '';
            final aOrderNo = a['order_no']?.toString() ?? '';
            final aOrder = (aShipTo.isNotEmpty && aOrderNo.isNotEmpty) ? '$aShipTo-$aOrderNo' : '$aShipTo$aOrderNo';
            
            final bShipTo = b['ship_to']?.toString() ?? '';
            final bOrderNo = b['order_no']?.toString() ?? '';
            final bOrder = (bShipTo.isNotEmpty && bOrderNo.isNotEmpty) ? '$bShipTo-$bOrderNo' : '$bShipTo$bOrderNo';
            
            bool aHasShowroom = aOrder.toUpperCase().contains('SHOWROOM');
            bool aHasStock = aOrder.toUpperCase().contains('STOCK');
            bool bHasShowroom = bOrder.toUpperCase().contains('SHOWROOM');
            bool bHasStock = bOrder.toUpperCase().contains('STOCK');
            
            // Helper function to get order priority (lower number = higher priority)
            int getOrderPriority(bool hasShowroom, bool hasStock) {
              if (!hasShowroom && !hasStock) return 1; // Numeric order (highest priority)
              if (hasShowroom) return 2; // SHOWROOM
              if (hasStock) return 3; // STOCK (lowest priority)
              return 4;
            }
            
            if (aValue.isEmpty && bValue.isEmpty) {
              // Both blank - compare by order type
              int aPriority = getOrderPriority(aHasShowroom, aHasStock);
              int bPriority = getOrderPriority(bHasShowroom, bHasStock);
              comparison = aPriority.compareTo(bPriority);
            } else if (aValue.isEmpty && bValue.isNotEmpty) {
              // a is blank, b has value - a comes first
              comparison = -1;
            } else if (aValue.isNotEmpty && bValue.isEmpty) {
              // a has value, b is blank - b comes first
              comparison = 1;
            } else {
              // Both have values - compare by order type first, then by value
              int aPriority = getOrderPriority(aHasShowroom, aHasStock);
              int bPriority = getOrderPriority(bHasShowroom, bHasStock);
              
              if (aPriority != bPriority) {
                comparison = aPriority.compareTo(bPriority);
              } else {
                comparison = aValue.compareTo(bValue);
              }
            }
            break;
          case 5: // QC Notes
            comparison = (a['qc_notes']?.toString() ?? '').compareTo(b['qc_notes']?.toString() ?? '');
            break;
          case 6: // Notes
            comparison = (a['notes']?.toString() ?? '').compareTo(b['notes']?.toString() ?? '');
            break;
        }
        
        return _sortAscending ? comparison : -comparison;
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '$tableName (${data.length} items)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                dataRowMinHeight: 100,
                dataRowMaxHeight: 120,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFC00000).withValues(alpha: 0.1)),
                columns: [
                  DataColumn(
                    label: const Text('Product', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('Order', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('Colour', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('Carcass QC', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('Final QC', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('QC Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                      });
                    },
                  ),
                ],
                rows: sortedData.map((item) {
                  // Prepare data
                  final product = item['product']?.toString() ?? '';
                  final shipTo = item['ship_to']?.toString() ?? '';
                  final orderNo = item['order_no']?.toString() ?? '';
                  final order = (shipTo.isNotEmpty && orderNo.isNotEmpty) 
                      ? '$shipTo-$orderNo' 
                      : '$shipTo$orderNo';
                  final colour = _cleanColourText(item['colour']?.toString());
                  final carcassQc = item['carcass_qc_day']?.toString() ?? '';
                  final finalQc = item['final_qc_date']?.toString() ?? '';
                  final qcNotes = item['qc_notes']?.toString() ?? '';
                  final notes = item['notes']?.toString() ?? '';
                  
                  return DataRow(
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            product,
                            softWrap: true,
                          ),
                        ),
                        onTap: () => _showDetailDialog(tableName, item),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            order,
                            softWrap: true,
                          ),
                        ),
                        onTap: () => _showDetailDialog(tableName, item),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            colour,
                            softWrap: true,
                          ),
                        ),
                        onTap: () => _showDetailDialog(tableName, item),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            carcassQc,
                            softWrap: true,
                          ),
                        ),
                        onTap: () => _showDetailDialog(tableName, item),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            finalQc,
                            softWrap: true,
                          ),
                        ),
                        onTap: () => _showDetailDialog(tableName, item),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            qcNotes,
                            softWrap: true,
                            maxLines: 5,
                          ),
                        ),
                        onTap: () => _showDetailDialog(tableName, item),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            notes,
                            softWrap: true,
                            maxLines: 5,
                          ),
                        ),
                        onTap: () => _showDetailDialog(tableName, item),
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

  void _showDetailDialog(String tableName, Map<String, dynamic> item) {
    // Map field names to display labels
    String getFieldLabel(String fieldName) {
      switch (fieldName) {
        case 'id': return 'ID';
        case 'no': return 'NO.';
        case 'ship_to': return 'SHIP TO';
        case 'order_no': return 'ORDER NO';
        case 'product': return 'PRODUCT';
        case 'colour': return 'COLOUR';
        case 'qty': return 'QTY';
        case 'size': return 'SIZE';
        case 'carcass_qc_day': return 'CARCASS DATE';
        case 'final_qc_date': return 'FINAL QC DATE';
        case 'deliver_to_warehouse': return 'WH';
        case 'qc_notes': return 'QC NOTES';
        case 'notes': return 'NOTES';
        default: return fieldName.toUpperCase();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item['product']?.toString() ?? 'Details',
          style: const TextStyle(color: Color(0xFFC00000)),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: item.entries
                .where((entry) => entry.key != 'image') // Exclude image field
                .map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${getFieldLabel(entry.key)}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(entry.value?.toString() ?? 'N/A'),
                    ),
                  ],
                ),
              );
            }).toList(),
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
}

// Search delegate for process data
class ProcessSearchDelegate extends SearchDelegate {
  final ApiService _apiService = ApiService();

  String _cleanColourText(String? colour) {
    if (colour == null || colour.isEmpty) return '';
    return colour
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
      future: _apiService.searchProcess(query),
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
                        DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Order', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Colour', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Carcass QC', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Final QC', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('QC Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: results.map((item) {
                        // Prepare data
                        final product = item['product']?.toString() ?? '';
                        final shipTo = item['ship_to']?.toString() ?? '';
                        final orderNo = item['order_no']?.toString() ?? '';
                        final order = (shipTo.isNotEmpty && orderNo.isNotEmpty) 
                            ? '$shipTo-$orderNo' 
                            : '$shipTo$orderNo';
                        // Format supplier/table name: "anh_thiep" -> "ANH THIEP"
                        final tableName = item['table_name']?.toString() ?? item['database']?.toString() ?? '';
                        final supplier = tableName.replaceAll('_', ' ').toUpperCase();
                        final colour = _cleanColourText(item['colour']?.toString());
                        final carcassQc = item['carcass_qc_day']?.toString() ?? '';
                        final finalQc = item['final_qc_date']?.toString() ?? '';
                        final qcNotes = item['qc_notes']?.toString() ?? '';
                        final notes = item['notes']?.toString() ?? '';
                        
                        return DataRow(
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 100),
                                child: Text(
                                  product,
                                  softWrap: true,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 120),
                                child: Text(
                                  order,
                                  softWrap: true,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Text(
                                  supplier,
                                  softWrap: true,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  colour,
                                  softWrap: true,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 100),
                                child: Text(
                                  carcassQc,
                                  softWrap: true,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 100),
                                child: Text(
                                  finalQc,
                                  softWrap: true,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 100),
                                child: Text(
                                  qcNotes,
                                  softWrap: true,
                                  maxLines: 5,
                                ),
                              ),
                              onTap: () => _showDetailDialog(context, item),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 100),
                                child: Text(
                                  notes,
                                  softWrap: true,
                                  maxLines: 5,
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

        return const Center(child: Text('No data'));
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Enter product name, order number, or colour to search'),
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> item) {
    // Map field names to display labels
    String getFieldLabel(String fieldName) {
      switch (fieldName) {
        case 'id': return 'ID';
        case 'no': return 'NO.';
        case 'ship_to': return 'SHIP TO';
        case 'order_no': return 'ORDER NO';
        case 'product': return 'PRODUCT';
        case 'colour': return 'COLOUR';
        case 'qty': return 'QTY';
        case 'size': return 'SIZE';
        case 'carcass_qc_day': return 'CARCASS DATE';
        case 'final_qc_date': return 'FINAL QC DATE';
        case 'deliver_to_warehouse': return 'WH';
        case 'qc_notes': return 'QC NOTES';
        case 'notes': return 'NOTES';
        default: return fieldName.toUpperCase();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item['product']?.toString() ?? 'Details',
          style: const TextStyle(color: Color(0xFFC00000)),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: item.entries
                .where((entry) => entry.key != 'image') // Exclude image field
                .map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${getFieldLabel(entry.key)}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(entry.value?.toString() ?? 'N/A'),
                    ),
                  ],
                ),
              );
            }).toList(),
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
}
