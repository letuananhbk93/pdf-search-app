import 'package:dio/dio.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initInterceptors(); // Initialize interceptors only once
  }

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pdf-search-backend-tlcvietnam-282948b11d32.herokuapp.com/',  // Mock base URL
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Interceptor tùy chọn: Log request/response cho debug
  void _initInterceptors() {
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
      ),
    );
  }

  // Gọi search API (sau thay baseUrl thành server thật)
  Future<List<dynamic>> searchPdfs(String query) async {
    try {
      final response = await _dio.get('search', queryParameters: {'query': query});  // Lấy 5 posts mock
      if (response.statusCode == 200) {
        return response.data;  // Trả list JSON
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  // Fetch colors data from /colors endpoint (all databases)
  Future<Map<String, List<dynamic>>> fetchColors() async {
    try {
      final response = await _dio.get('colors');
      if (response.statusCode == 200) {
        return Map<String, List<dynamic>>.from(response.data);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  // Fetch specific color database
  Future<List<dynamic>> fetchColorTable(String tableName) async {
    try {
      print('Fetching color table: $tableName');
      print('URL: ${_dio.options.baseUrl}colors/$tableName');
      
      final response = await _dio.get('colors/$tableName');
      
      print('Response status: ${response.statusCode}');
      print('Response data type: ${response.data.runtimeType}');
      print('Response data: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<dynamic>.from(response.data);
        } else if (response.data is Map) {
          // If backend returns {data: [...]} format
          if (response.data['data'] != null && response.data['data'] is List) {
            return List<dynamic>.from(response.data['data']);
          }
          // If backend returns the data directly in a map with table name
          if (response.data[tableName] != null && response.data[tableName] is List) {
            return List<dynamic>.from(response.data[tableName]);
          }
        }
        throw Exception('Unexpected response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('DioException: ${e.type}');
      print('Error message: ${e.message}');
      print('Response: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('General error: $e');
      throw Exception('Error: $e');
    }
  }

  // Search across all color databases
  Future<List<dynamic>> searchColors(String query) async {
    try {
      print('Searching colors: $query');
      final response = await _dio.get('colors/search', queryParameters: {'query': query});
      
      print('Search response status: ${response.statusCode}');
      print('Search response data type: ${response.data.runtimeType}');
      print('Search response full data: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<dynamic>.from(response.data);
        } else if (response.data is Map) {
          // If backend returns {results: [...]} format
          if (response.data['results'] != null && response.data['results'] is List) {
            return List<dynamic>.from(response.data['results']);
          }
          // If backend returns {table1: [...], table2: [...]} format
          // Combine all results into one list
          List<dynamic> allResults = [];
          response.data.forEach((key, value) {
            if (value is List) {
              allResults.addAll(value);
            }
          });
          return allResults;
        }
        throw Exception('Unexpected search response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Search DioException: ${e.type}');
      print('Search error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Search general error: $e');
      throw Exception('Error: $e');
    }
  }
}