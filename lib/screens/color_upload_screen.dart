import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/color_upload_service.dart';

class ColorUploadScreen extends StatefulWidget {
  const ColorUploadScreen({super.key});

  @override
  State<ColorUploadScreen> createState() => _ColorUploadScreenState();
}

class _ColorUploadScreenState extends State<ColorUploadScreen> {
  final ColorUploadService _uploadService = ColorUploadService();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _statusMessage;
  Map<String, dynamic>? _uploadResult;

  /// Pick Excel file
  Future<void> _pickFile() async {
    setState(() {
      _statusMessage = null;
      _uploadResult = null;
    });

    PlatformFile? file = await _uploadService.pickExcelFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _statusMessage = 'File selected: ${file.name}';
      });
    }
  }

  /// Upload file to Heroku
  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file first')),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading...';
    });

    try {
      Map<String, dynamic> result = await _uploadService.uploadColorExcel(_selectedFile!);
      
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadResult = result;
          
          if (result['success'] == true) {
            _statusMessage = '✅ Upload successful!';
          } else {
            _statusMessage = '❌ Upload failed: ${result['error']}';
          }
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result['total_records']} records uploaded!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = '❌ Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload Color Excel',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Download Color Excel file to your device'),
                    const Text('2. Click "Select Excel File" below'),
                    const Text('3. Choose the Excel file (.xlsx or .xls)'),
                    const Text('4. Click "Upload to Server"'),
                    const Text('5. Wait for confirmation'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Select File Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: const Icon(Icons.file_upload),
              label: const Text('Select Excel File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 10),

            // Upload Button
            ElevatedButton.icon(
              onPressed: (_selectedFile != null && !_isUploading) ? _uploadFile : null,
              icon: _isUploading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload to Server'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 20),

            // Status Message
            if (_statusMessage != null)
              Card(
                color: _uploadResult?['success'] == true ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),

            // Upload Result Details
            if (_uploadResult != null && _uploadResult!['success'] == true)
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(top: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Details:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          Text('Sheets Processed: ${_uploadResult!['sheets_processed']}'),
                          Text('Total Records: ${_uploadResult!['total_records']}'),
                          const SizedBox(height: 10),
                          const Text('Tables:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...(_uploadResult!['tables'] as Map).entries.map(
                            (entry) => Text('  • ${entry.key}: ${entry.value} records'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
