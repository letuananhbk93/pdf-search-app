import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String filename;

  const PdfViewerScreen({super.key, required this.pdfUrl, required this.filename});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfController pdfController;
  bool isLoading = true;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // Use Dio to download PDF data
      final dio = Dio();
      final response = await dio.get(
        widget.pdfUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      final pdfData = Uint8List.fromList(response.data);
      
      pdfController = PdfController(
        document: PdfDocument.openData(pdfData),
      );
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    if (!isLoading && errorMessage == null) {
      pdfController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Lỗi load PDF: $errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Quay lại'),
                      ),
                    ],
                  ),
                )
              : PdfView(
                  controller: pdfController,
                  onDocumentLoaded: (document) {
                    // PDF loaded successfully with ${document.pagesCount} pages
                    // You can add proper logging here if needed
                  },
                  onDocumentError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi load PDF: ${error.toString()}'),
                        backgroundColor: Colors.red,
                        action: SnackBarAction(
                          label: 'Thử lại',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}