import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../models/drawing_models.dart';

class UploadDrawingsScreen extends StatefulWidget {
  const UploadDrawingsScreen({super.key});

  @override
  State<UploadDrawingsScreen> createState() => _UploadDrawingsScreenState();
}

class _UploadDrawingsScreenState extends State<UploadDrawingsScreen> {
  final ApiService _apiService = ApiService();
  
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  UploadResult? _uploadResult;

  Future<void> _selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true, // Important for web - loads bytes
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
          _uploadResult = null; // Clear previous results
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting files: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty) {
        _uploadResult = null;
      }
    });
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      _showErrorSnackBar('Please select at least one PDF file');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadResult = null;
    });

    try {
      // Simulate progress for better UX
      for (double i = 0.1; i <= 0.9; i += 0.1) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() {
            _uploadProgress = i;
          });
        }
      }

      // Call the updated API method with PlatformFile objects
      final result = await _apiService.uploadDrawingsFromFiles(_selectedFiles);
      
      setState(() {
        _uploadProgress = 1.0;
        _uploadResult = UploadResult.fromJson(result);
        _isUploading = false;
      });

      // Show success message
      if (_uploadResult!.successCount > 0) {
        _showSuccessSnackBar('${_uploadResult!.successCount} drawings uploaded successfully!');
      }

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      _showErrorSnackBar('Upload failed: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload Drawings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedFiles.isNotEmpty && !_isUploading)
            IconButton(
              onPressed: _uploadFiles,
              icon: const Icon(Icons.upload, color: Colors.white),
              tooltip: 'Upload Files',
            ),
        ],
      ),
      body: Column(
        children: [
          // File picker section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _selectFiles,
                  icon: const Icon(Icons.file_upload),
                  label: Text(
                    _selectedFiles.isEmpty 
                        ? 'Select PDF Files' 
                        : 'Add More Files (${_selectedFiles.length} selected)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC00000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select one or more PDF files to upload',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          // Upload progress
          if (_isUploading) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[300],
                    color: const Color(0xFFC00000),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading... ${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],

          // Selected files list
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Selected Files (${_selectedFiles.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Files list
          Expanded(
            child: _selectedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No files selected',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Select PDF Files" to choose drawings to upload',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedFiles.length + (_uploadResult != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show upload results at the end
                      if (index == _selectedFiles.length && _uploadResult != null) {
                        return _buildUploadResults();
                      }
                      
                      // Show selected files
                      final file = _selectedFiles[index];
                      final fileName = file.name;
                      final fileSize = _getFileSize(file);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          title: Text(
                            fileName,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            fileSize,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          trailing: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  onPressed: () => _removeFile(index),
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  tooltip: 'Remove file',
                                ),
                        ),
                      );
                    },
                  ),
          ),

          // Upload button (bottom)
          if (_selectedFiles.isNotEmpty && !_isUploading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _uploadFiles,
                icon: const Icon(Icons.cloud_upload),
                label: Text('Upload ${_selectedFiles.length} File(s)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC00000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadResults() {
    if (_uploadResult == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Results',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          // Success summary
          if (_uploadResult!.successCount > 0) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_uploadResult!.successCount} files uploaded successfully',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            // List successful uploads
            ...(_uploadResult!.uploaded.map((item) => Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(
                '• ${item.filename}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ))),
          ],
          
          // Error summary
          if (_uploadResult!.errorCount > 0) ...[
            if (_uploadResult!.successCount > 0) const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_uploadResult!.errorCount} files failed',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            // List failed uploads
            ...(_uploadResult!.errors.map((error) => Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${error.filename}',
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      error.error,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ),
                ],
              ),
            ))),
          ],
          
          // Action buttons
          if (_uploadResult!.successCount > 0 || _uploadResult!.errorCount > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_uploadResult!.successCount > 0) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, true); // Return success flag
                    },
                    icon: const Icon(Icons.done, size: 16),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedFiles.clear();
                      _uploadResult = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Upload More'),
                ),
              ],
            ),
          ],
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