// ignore_for_file: avoid_print

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ColorUploadService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pdf-search-backend-tlcvietnam-282948b11d32.herokuapp.com/',
      connectTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  /// Pick Excel file from device
  Future<PlatformFile?> pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: kIsWeb, // Load bytes for web
      );

      if (result != null) {
        return result.files.single;
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  /// Upload Color Excel file to Heroku
  Future<Map<String, dynamic>> uploadColorExcel(PlatformFile file) async {
    try {
      String fileName = file.name;
      
      MultipartFile multipartFile;
      
      if (kIsWeb) {
        // For web: use bytes
        if (file.bytes == null) {
          return {
            'success': false,
            'error': 'File bytes not available',
          };
        }
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: fileName,
        );
      } else {
        // For mobile/desktop: use path
        if (file.path == null) {
          return {
            'success': false,
            'error': 'File path not available',
          };
        }
        multipartFile = await MultipartFile.fromFile(
          file.path!,
          filename: fileName,
        );
      }
      
      FormData formData = FormData.fromMap({
        'file': multipartFile,
      });

      final response = await _dio.post(
        'upload-colors-excel',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Debug: Print the full response to see the structure
        print('=== Upload Response ===');
        print('Full response: ${response.data}');
        print('Response type: ${response.data.runtimeType}');
        
        // Calculate total records from tables if not provided directly
        int totalRecords = response.data['total_records'] ?? 0;
        
        // If total_records is 0, try to sum from tables
        if (totalRecords == 0 && response.data['tables'] != null) {
          final tables = response.data['tables'];
          if (tables is Map) {
            totalRecords = tables.values.fold(0, (sum, count) => sum + (count as int? ?? 0));
          }
        }
        
        return {
          'success': true,
          'sheets_processed': response.data['sheets_processed'] ?? 0,
          'total_records': totalRecords,
          'tables': response.data['tables'] ?? {},
        };
      } else {
        return {
          'success': false,
          'error': 'Server returned status ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Network error occurred',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
