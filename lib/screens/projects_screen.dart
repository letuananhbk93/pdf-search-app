// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'process_upload_screen.dart';

const double _kProcessRowHeight = 110;

/// Excel cell fill ("#RRGGBB") stored by the backend; null when the cell had no fill.
Color? _parseExcelColor(dynamic value) {
  final match = RegExp(r'^#?([0-9A-Fa-f]{6})$').firstMatch(value?.toString().trim() ?? '');
  if (match == null) return null;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

/// "dd/mm" for date values (also handles ISO strings from older uploads); any other text is shown as is.
String _formatQcDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'NaT' || text == 'None' || text == 'nan') return '';
  final iso = RegExp(r'^\d{4}-(\d{2})-(\d{2})(?:[ T]\d{2}:\d{2}:\d{2}.*)?$').firstMatch(text);
  if (iso != null) return '${iso.group(2)}/${iso.group(1)}';
  return text;
}

/// Sorts dd/mm values chronologically (month first), with non-date text after them.
String _qcSortKey(String formatted) {
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})$').firstMatch(formatted);
  if (match == null) return '1$formatted';
  return '0${match.group(2)!.padLeft(2, '0')}${match.group(1)!.padLeft(2, '0')}';
}

DataCell _processCell({
  required String text,
  required double width,
  required VoidCallback onTap,
  Color? color,
  int? maxLines,
}) {
  final darkFill = color != null && color.computeLuminance() < 0.4;
  return DataCell(
    Container(
      width: width,
      height: _kProcessRowHeight,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        softWrap: true,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: darkFill ? const TextStyle(color: Colors.white) : null,
      ),
    ),
    onTap: onTap,
  );
}

/// Header label sized so header + sort arrow equal the body cell width.
Widget _processHeader(String label, double width) {
  return Padding(
    padding: const EdgeInsets.only(left: 12),
    child: SizedBox(
      width: width - 12 - 18,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

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
  String? _lastUpdateDate; // Track last update date
  
  TabController? _tabController;
  List<String> _tabNames = [];
  
  int? _sortColumnIndex;
  bool _sortAscending = true;

  static const _columns = [
    (label: 'Product', width: 160.0),
    (label: 'Order', width: 130.0),
    (label: 'Colour', width: 190.0),
    (label: 'Carcass QC', width: 130.0),
    (label: 'Final QC', width: 120.0),
    (label: 'QC Notes', width: 160.0),
    (label: 'Notes', width: 160.0),
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _fetchLastUpdateDate();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // Fetch last update date from API
  Future<void> _fetchLastUpdateDate([String? projectName]) async {
    try {
      print('DEBUG: Fetching update date for project: $projectName');
      
      String category;
      if (projectName != null) {
        // Format project name for API (convert to lowercase with underscores)
        category = _formatProjectNameForApi(projectName);
        print('DEBUG: Formatted project name for API: $category');
      } else {
        category = 'projects';
      }
      
      print('DEBUG: Using category: $category');
      
      final updateInfo = await _apiService.getLastUpdateInfo(category);
      print('DEBUG: Update info received: $updateInfo');
      
      setState(() {
        _lastUpdateDate = updateInfo['last_update'] ?? 'Unknown';
      });
    } catch (e) {
      print('DEBUG: Error fetching update date: $e');
      setState(() {
        _lastUpdateDate = 'Unknown';
      });
    }
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

  // Format project name for API calls (convert to lowercase with underscores)
  String _formatProjectNameForApi(String projectName) {
    // Convert from display name back to API format
    // "PROJECT ABC" -> "project_abc"
    return projectName.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _error = null;
    });

    try {
      final projects = await _apiService.fetchProjects();
      print('DEBUG: Loaded projects: $projects');
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
      
      // Fetch project-specific update date
      print('DEBUG: About to fetch update date for project: "$projectName"');
      _fetchLastUpdateDate(projectName);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingData = false;
      });
    }
  }

  void _onProjectSelected(String? projectName) {
    if (projectName != null && projectName != _selectedProject) {
      print('DEBUG: Project selected: "$projectName"');
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
          'TIMELINE',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),
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
                case 'upload':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProcessUploadScreen(),
                    ),
                  ).then((_) {
                    // Reload data and update date after returning from upload
                    if (_selectedProject != null) {
                      _loadProjectData(_selectedProject!);
                    }
                    // Update date will be fetched in _loadProjectData
                  });
                  break;
                case 'refresh':
                  if (_selectedProject != null) {
                    _loadProjectData(_selectedProject!);
                  } else {
                    _loadProjects();
                  }
                  // Update date will be fetched in _loadProjectData or use general
                  if (_selectedProject == null) {
                    _fetchLastUpdateDate();
                  }
                  break;
                case 'search':
                  showSearch(
                    context: context,
                    delegate: ProcessSearchDelegate(),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
            final aValue = _formatQcDate(a['carcass_qc_day']);
            final bValue = _formatQcDate(b['carcass_qc_day']);
            
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
                comparison = _qcSortKey(aValue).compareTo(_qcSortKey(bValue));
              }
            }
            break;
          case 4: // Final QC
            final aValue = _formatQcDate(a['final_qc_date']);
            final bValue = _formatQcDate(b['final_qc_date']);
            
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
                comparison = _qcSortKey(aValue).compareTo(_qcSortKey(bValue));
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
                columnSpacing: 0,
                horizontalMargin: 0,
                dataRowMinHeight: _kProcessRowHeight,
                dataRowMaxHeight: _kProcessRowHeight,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFC00000).withValues(alpha: 0.1)),
                columns: [
                  for (final column in _columns)
                    DataColumn(
                      label: _processHeader(column.label, column.width),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                        });
                      },
                    ),
                ],
                rows: sortedData.map((item) {
                  final shipTo = item['ship_to']?.toString() ?? '';
                  final orderNo = item['order_no']?.toString() ?? '';
                  final order = (shipTo.isNotEmpty && orderNo.isNotEmpty)
                      ? '$shipTo-$orderNo'
                      : '$shipTo$orderNo';
                  void open() => _showDetailDialog(tableName, item);

                  return DataRow(
                    cells: [
                      _processCell(text: item['product']?.toString() ?? '', width: _columns[0].width, onTap: open),
                      _processCell(text: order, width: _columns[1].width, color: _parseExcelColor(item['order_color']), onTap: open),
                      _processCell(text: _cleanColourText(item['colour']?.toString()), width: _columns[2].width, onTap: open),
                      _processCell(text: _formatQcDate(item['carcass_qc_day']), width: _columns[3].width, color: _parseExcelColor(item['carcass_color']), onTap: open),
                      _processCell(text: _formatQcDate(item['final_qc_date']), width: _columns[4].width, color: _parseExcelColor(item['final_color']), onTap: open),
                      _processCell(text: item['qc_notes']?.toString() ?? '', width: _columns[5].width, maxLines: 5, onTap: open),
                      _processCell(text: item['notes']?.toString() ?? '', width: _columns[6].width, maxLines: 5, onTap: open),
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
                .where((entry) => entry.key != 'image' && !entry.key.endsWith('_color')) // Exclude image and fill-color fields
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
                      child: Text(
                        (entry.key == 'carcass_qc_day' || entry.key == 'final_qc_date')
                            ? _formatQcDate(entry.value)
                            : (entry.value?.toString() ?? 'N/A'),
                      ),
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

  static const _columns = [
    (label: 'Product', width: 160.0),
    (label: 'Order', width: 130.0),
    (label: 'Supplier', width: 150.0),
    (label: 'Colour', width: 190.0),
    (label: 'Carcass QC', width: 130.0),
    (label: 'Final QC', width: 120.0),
    (label: 'QC Notes', width: 160.0),
    (label: 'Notes', width: 160.0),
  ];

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
                      columnSpacing: 0,
                      horizontalMargin: 0,
                      dataRowMinHeight: _kProcessRowHeight,
                      dataRowMaxHeight: _kProcessRowHeight,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFC00000).withValues(alpha: 0.1)),
                      columns: [
                        for (final column in _columns)
                          DataColumn(label: _processHeader(column.label, column.width)),
                      ],
                      rows: results.map((item) {
                        final shipTo = item['ship_to']?.toString() ?? '';
                        final orderNo = item['order_no']?.toString() ?? '';
                        final order = (shipTo.isNotEmpty && orderNo.isNotEmpty)
                            ? '$shipTo-$orderNo'
                            : '$shipTo$orderNo';
                        // Format supplier/table name: "anh_thiep" -> "ANH THIEP"
                        final tableName = item['table_name']?.toString() ?? item['database']?.toString() ?? '';
                        final supplier = tableName.replaceAll('_', ' ').toUpperCase();
                        void open() => _showDetailDialog(context, item);

                        return DataRow(
                          cells: [
                            _processCell(text: item['product']?.toString() ?? '', width: _columns[0].width, onTap: open),
                            _processCell(text: order, width: _columns[1].width, color: _parseExcelColor(item['order_color']), onTap: open),
                            _processCell(text: supplier, width: _columns[2].width, onTap: open),
                            _processCell(text: _cleanColourText(item['colour']?.toString()), width: _columns[3].width, onTap: open),
                            _processCell(text: _formatQcDate(item['carcass_qc_day']), width: _columns[4].width, color: _parseExcelColor(item['carcass_color']), onTap: open),
                            _processCell(text: _formatQcDate(item['final_qc_date']), width: _columns[5].width, color: _parseExcelColor(item['final_color']), onTap: open),
                            _processCell(text: item['qc_notes']?.toString() ?? '', width: _columns[6].width, maxLines: 5, onTap: open),
                            _processCell(text: item['notes']?.toString() ?? '', width: _columns[7].width, maxLines: 5, onTap: open),
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
                .where((entry) => entry.key != 'image' && !entry.key.endsWith('_color')) // Exclude image and fill-color fields
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
                      child: Text(
                        (entry.key == 'carcass_qc_day' || entry.key == 'final_qc_date')
                            ? _formatQcDate(entry.value)
                            : (entry.value?.toString() ?? 'N/A'),
                      ),
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
