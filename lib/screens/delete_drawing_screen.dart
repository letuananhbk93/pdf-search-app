import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/drawing_models.dart';

class DeleteDrawingScreen extends StatefulWidget {
  const DeleteDrawingScreen({super.key});

  @override
  State<DeleteDrawingScreen> createState() => _DeleteDrawingScreenState();
}

class _DeleteDrawingScreenState extends State<DeleteDrawingScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<DrawingSearchResult> _searchResults = [];
  DrawingSearchResult? _selectedDrawingToDelete;
  bool _isSearching = false;
  bool _isDeleting = false;
  DeleteResult? _deleteResult;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchDrawings(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
      _searchResults = [];
      _selectedDrawingToDelete = null;
    });

    try {
      final results = await _apiService.searchDrawings(query, limit: 20);
      
      setState(() {
        _searchResults = results.map((json) => DrawingSearchResult.fromJson(json)).toList();
        _isSearching = false;
      });

      if (_searchResults.isEmpty) {
        _showInfoSnackBar('No drawings found for "$query"');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showErrorSnackBar('Search failed: $e');
    }
  }

  void _selectDrawingToDelete(DrawingSearchResult drawing) {
    setState(() {
      _selectedDrawingToDelete = drawing;
    });
  }

  Future<void> _showConfirmationDialog() async {
    if (_selectedDrawingToDelete == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Confirm Deletion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this drawing?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Filename: ${_selectedDrawingToDelete!.filename}'),
              const SizedBox(height: 12),
              const Text(
                '⚠️ This action cannot be undone. The drawing will be permanently deleted from both cloud storage and the search index.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteDrawing();
    }
  }

  Future<void> _deleteDrawing() async {
    if (_selectedDrawingToDelete == null) return;

    setState(() {
      _isDeleting = true;
      _deleteResult = null;
    });

    try {
      final result = await _apiService.deleteDrawing(_selectedDrawingToDelete!.id);
      
      setState(() {
        _deleteResult = DeleteResult.fromJson(result);
        _isDeleting = false;
        // Clear selection after successful delete
        _selectedDrawingToDelete = null;
        // Refresh search to show updated results
        if (_searchQuery.isNotEmpty) {
          _searchDrawings(_searchQuery);
        }
      });

      if (_deleteResult!.success) {
        _showSuccessSnackBar('Drawing deleted successfully!');
      } else {
        _showErrorSnackBar('Delete failed: ${_deleteResult!.message}');
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });
      _showErrorSnackBar('Delete failed: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Drawing'),
        backgroundColor: Colors.red.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Delete Drawing Process:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('1. Search for the drawing you want to delete'),
                  Text('2. Select the drawing from the results'),
                  Text('3. Confirm deletion (this action cannot be undone)'),
                  Text('4. Drawing will be removed from both storage and search index'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Search Box
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for drawing to delete',
                hintText: 'Enter drawing name...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchDrawings('');
                            },
                          )
                        : null,
              ),
              onChanged: (value) {
                // Only clear results when text is empty, don't auto-search
                if (value.isEmpty) {
                  _searchDrawings('');
                }
              },
              onSubmitted: _searchDrawings,
            ),
            
            const SizedBox(height: 16),
            
            // Search Results
            if (_searchResults.isNotEmpty) ...[
              Text(
                'Found ${_searchResults.length} drawing(s) for "$_searchQuery"',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final drawing = _searchResults[index];
                    final isSelected = _selectedDrawingToDelete?.id == drawing.id;
                    
                    return Card(
                      color: isSelected ? Colors.red.shade100 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Text(
                            drawing.filename.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        title: Text(drawing.filename),
                        subtitle: Text('ID: ${drawing.id}'),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Colors.red.shade700)
                            : const Icon(Icons.circle_outlined),
                        onTap: () => _selectDrawingToDelete(drawing),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_isSearching) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Searching drawings...'),
                    ],
                  ),
                ),
              ),
            ] else if (_searchQuery.isNotEmpty && !_isSearching) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No drawings found',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Search for a drawing to delete',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Delete Button
            if (_selectedDrawingToDelete != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _showConfirmationDialog,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_forever, color: Colors.white),
                  label: Text(
                    _isDeleting ? 'Deleting...' : 'Delete Selected Drawing',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            
            // Delete Result
            if (_deleteResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _deleteResult!.success ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(
                    color: _deleteResult!.success ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _deleteResult!.success ? Icons.check_circle : Icons.error,
                          color: _deleteResult!.success ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _deleteResult!.success ? 'Delete Successful!' : 'Delete Failed!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _deleteResult!.success ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_deleteResult!.message),
                    if (_deleteResult!.filename != null) ...[
                      const SizedBox(height: 4),
                      Text('Deleted: ${_deleteResult!.filename}'),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}