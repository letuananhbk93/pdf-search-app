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
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
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
}