import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class DimsScreen extends ConsumerStatefulWidget {
  const DimsScreen({super.key});

  @override
  ConsumerState<DimsScreen> createState() => _DimsScreenState();
}

class _DimsScreenState extends ConsumerState<DimsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Map<String, List<dynamic>>? _cachedData;
  bool _isLoading = false;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Starting to load dims data...');
      final data = await _apiService.fetchAllDims();
      print('✓ Successfully loaded dims data');
      
      if (mounted) {
        setState(() {
          _cachedData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Failed to load dims data: $e');
      
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PACKAGE DIMS',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context,
                delegate: DimsSearchDelegate(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.red,
            tabs: const [
              Tab(text: 'STANDARD'),
              Tab(text: 'CUSTOM'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading package dimensions...'),
                        SizedBox(height: 8),
                        Text(
                          'This may take a few seconds',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
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
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabContent('standard'),
                          _buildTabContent('custom'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(String type) {
    if (_cachedData == null) {
      return const Center(child: Text('No data loaded'));
    }

    final key = type == 'standard' ? 'standard_dims' : 'custom_dims';
    final data = _cachedData![key] ?? [];

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

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        
        // Build dims string from individual measurements
        String dimsStr = 'N/A';
        if (item['length'] != null || item['width'] != null || item['height'] != null) {
          final l = item['length']?.toString() ?? '-';
          final w = item['width']?.toString() ?? '-';
          final h = item['height']?.toString() ?? '-';
          dimsStr = 'L$l x W$w x H$h';
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(
              item['product_name'] ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Dims: $dimsStr'),
                if (item['supplier'] != null)
                  Text('Supplier: ${item['supplier']}'),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showDetailDialog(context, item, type);
            },
          ),
        );
      },
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> item, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['product_name'] ?? 'Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', item['id']),
              _buildDetailRow('Product Name', item['product_name']),
              
              // Standard dims fields
              if (type == 'standard') ...[
                _buildDetailRow('Collection', item['collection']),
                _buildDetailRow('Category', item['cat']),
                _buildDetailRow('Sub-Category', item['subcat']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('Packaging', item['packaging']),
              ],
              
              // Custom dims fields
              if (type == 'custom') ...[
                _buildDetailRow('Order No', item['order_no']),
                _buildDetailRow('SKU', item['sku']),
                _buildDetailRow('Color', item['color']),
                _buildDetailRow('PO No', item['po_no']),
                _buildDetailRow('CBM', item['cbm']),
                _buildDetailRow('Packaging', item['packaging']),
              ],
              
              // Common fields
              _buildDetailRow('Supplier', item['supplier']),
              const Divider(),
              _buildDetailRow('Length', item['length']),
              _buildDetailRow('Width', item['width']),
              _buildDetailRow('Height', item['height']),
              _buildDetailRow('Weight', item['weight']),
              
              if (type == 'standard')
                _buildDetailRow('Date', item['ngay_thuc_hien']),
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

// Search delegate for searching dims
class DimsSearchDelegate extends SearchDelegate {
  final ApiService _apiService = ApiService();

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
      future: _apiService.searchDims(query),
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
              
              // Build dims string from individual measurements
              String dimsStr = 'N/A';
              if (item['length'] != null || item['width'] != null || item['height'] != null) {
                final l = item['length']?.toString() ?? '-';
                final w = item['width']?.toString() ?? '-';
                final h = item['height']?.toString() ?? '-';
                dimsStr = 'L$l x W$w x H$h';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    item['product_name'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Dims: $dimsStr'),
                      if (item['type'] != null)
                        Text(
                          'Type: ${item['type']}',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                          ),
                        ),
                      if (item['supplier'] != null)
                        Text('Supplier: ${item['supplier']}'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showDetailDialogSearch(context, item);
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

  void _showDetailDialogSearch(BuildContext context, Map<String, dynamic> item) {
    final type = item['type'] ?? 'unknown';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['product_name'] ?? 'Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', item['id']),
              _buildDetailRow('Product Name', item['product_name']),
              _buildDetailRow('Type', type),
              
              // Standard dims fields
              if (type == 'standard') ...[
                _buildDetailRow('Collection', item['collection']),
                _buildDetailRow('Category', item['cat']),
                _buildDetailRow('Sub-Category', item['subcat']),
                _buildDetailRow('Status', item['status']),
                _buildDetailRow('Packaging', item['packaging']),
              ],
              
              // Custom dims fields
              if (type == 'custom') ...[
                _buildDetailRow('Order No', item['order_no']),
                _buildDetailRow('SKU', item['sku']),
                _buildDetailRow('Color', item['color']),
                _buildDetailRow('PO No', item['po_no']),
                _buildDetailRow('CBM', item['cbm']),
                _buildDetailRow('Packaging', item['packaging']),
              ],
              
              // Common fields
              _buildDetailRow('Supplier', item['supplier']),
              const Divider(),
              _buildDetailRow('Length', item['length']),
              _buildDetailRow('Width', item['width']),
              _buildDetailRow('Height', item['height']),
              _buildDetailRow('Weight', item['weight']),
              
              if (type == 'standard')
                _buildDetailRow('Date', item['ngay_thuc_hien']),
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
