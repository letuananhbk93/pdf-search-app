// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:dio/dio.dart';

class PdfThumbnail extends StatelessWidget {
  final String pdfUrl;
  final double size;

  const PdfThumbnail({
    super.key,
    required this.pdfUrl,
    this.size = 50.0,
  });

  Future<Image?> _loadThumbnail() async {
    try {
      print('Loading thumbnail from: $pdfUrl');
      final dio = Dio();
      
      print('Downloading PDF...');
      final response = await dio.get(pdfUrl,
          options: Options(responseType: ResponseType.bytes));
      
      print('PDF downloaded, size: ${response.data.length} bytes');
      
      print('Opening PDF document...');
      final document = await PdfDocument.openData(response.data);
      
      print('Getting first page...');
      final page = await document.getPage(1); // First page (1-indexed)
      
      print('Rendering page...');
      final pageImage = await page.render(
        width: size * 2.0, // Higher resolution for crispness
        height: size * 2.0,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      
      await page.close();
      await document.close();
      
      print('Thumbnail loaded successfully!');
      return Image.memory(
        pageImage!.bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } catch (e, stackTrace) {
      print('Error loading thumbnail: $e');
      print('Stack trace: $stackTrace');
      return null; // Return null on error, will show fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<Image?>(
        future: _loadThumbnail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          } else if (snapshot.hasError || snapshot.data == null) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: Colors.grey,
              ),
            );
          } else {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: snapshot.data!,
            );
          }
        },
      ),
    );
  }
}