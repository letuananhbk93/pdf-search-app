import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../models/drawing_models.dart';

class UpdateDrawingScreen extends StatefulWidget {
  const UpdateDrawingScreen({super.key});

  @override
  State<UpdateDrawingScreen> createState() => _UpdateDrawingScreenState();
}

class _UpdateDrawingScreenState extends State<UpdateDrawingScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  PlatformFile? _selectedNewFile;
  List<DrawingSearchResult> _searchResults = [];
  DrawingSearchResult? _selectedDrawingToReplace;
  bool _isSearching = false;
  bool _isUpdating = false;
  UpdateResult? _updateResult;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectNewFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true, // Important for web - loads bytes
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedNewFile = result.files.first;
          _updateResult = null; // Clear previous results
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting file: $e');
    }
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
      _selectedDrawingToReplace = null;
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

  void _selectDrawingToReplace(DrawingSearchResult drawing) {
    setState(() {
      _selectedDrawingToReplace = drawing;
    });
  }

  Future<void> _showConfirmationDialog() async {
    if (_selectedNewFile == null || _selectedDrawingToReplace == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Replacement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to replace this drawing?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        const Text('Replace:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_selectedDrawingToReplace!.filename),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.upload_file, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        const Text('With:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_selectedNewFile!.name),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This action cannot be undone. The original file will be permanently replaced.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _performUpdate();
    }
  }

  Future<void> _performUpdate() async {
    if (_selectedNewFile == null || _selectedDrawingToReplace == null) return;

    setState(() {
      _isUpdating = true;
      _updateResult = null;
    });

    try {
      final result = await _apiService.updateDrawingFromFile(
        _selectedDrawingToReplace!.id,
        _selectedNewFile!,
      );

      setState(() {
        _updateResult = UpdateResult.fromJson(result);
        _isUpdating = false;
      });

      if (_updateResult!.success) {
        _showSuccessSnackBar(_updateResult!.message);
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      _showErrorSnackBar('Update failed: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Update Drawing',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _updateResult != null ? _buildSuccessView() : _buildMainView(),
    );
  }

  Widget _buildMainView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Select new file
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _selectedNewFile != null ? Colors.green : const Color(0xFFC00000),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select New PDF File',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedNewFile == null) ...[
                  ElevatedButton.icon(
                    onPressed: _selectNewFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Choose PDF File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC00000),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedNewFile!.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _getFileSize(_selectedNewFile!),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedNewFile = null;
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          tooltip: 'Remove file',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Step 2: Search existing drawing
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _selectedNewFile != null ? const Color(0xFFC00000) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Search Drawing to Replace',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  enabled: _selectedNewFile != null,
                  decoration: InputDecoration(
                    hintText: _selectedNewFile != null 
                        ? 'Enter drawing name to search...' 
                        : 'Select a new file first',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching 
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (query) {
                    // Use a debouncer to avoid too many API calls
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (_searchController.text == query && query.trim().isNotEmpty) {
                        _searchDrawings(query);
                      } else if (query.trim().isEmpty) {
                        setState(() {
                          _searchResults = [];
                          _searchQuery = '';
                          _selectedDrawingToReplace = null;
                        });
                      }
                    });
                  },
                  onSubmitted: _searchDrawings,
                ),
              ],
            ),
          ),

          // Search results
          if (_searchQuery.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _isSearching 
                    ? 'Searching for "$_searchQuery"...'
                    : 'Search Results for "$_searchQuery" (${_searchResults.length} found)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            
            if (_searchResults.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final drawing = _searchResults[index];
                  final isSelected = _selectedDrawingToReplace?.id == drawing.id;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? Colors.blue[50] : null,
                    child: ListTile(
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: drawing.thumbnailUrl != null && drawing.thumbnailUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  drawing.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                              ),
                      ),
                      title: Text(
                        drawing.filename,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('ID: ${drawing.id}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _selectDrawingToReplace(drawing),
                    ),
                  );
                },
              ),
            ] else if (!_isSearching && _searchQuery.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No drawings found. Try a different search term.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ],

          // Update button
          if (_selectedNewFile != null && _selectedDrawingToReplace != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _showConfirmationDialog,
                icon: _isUpdating 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz),
                label: Text(_isUpdating ? 'Updating...' : 'Replace Drawing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC00000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _updateResult!.success ? Icons.check_circle : Icons.error,
            size: 80,
            color: _updateResult!.success ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            _updateResult!.success ? 'Drawing Updated Successfully!' : 'Update Failed',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _updateResult!.message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (_updateResult!.success) ...[
                  Text(
                    'File: ${_updateResult!.filename}',
                    style: TextStyle(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, _updateResult!.success);
                },
                icon: const Icon(Icons.done),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedNewFile = null;
                    _searchResults = [];
                    _selectedDrawingToReplace = null;
                    _updateResult = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Update Another'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFileSize(PlatformFile file) {
    try {
      final bytes = file.size;
      if (bytes < 1024) return '${bytes} B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown size';
    }
  }
}