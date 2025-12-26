// ignore_for_file: avoid_print

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
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Interceptor tùy chọn: Log request/response cho debug
  void _initInterceptors() {
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: false,  // Don't log large response bodies
        requestHeader: false,
        logPrint: (obj) {
          // Only log important info, skip large responses
          if (obj.toString().length < 1000) {
            print(obj);
          } else {
            print('${obj.toString().substring(0, 200)}... [truncated ${obj.toString().length} chars]');
          }
        },
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

  // Fetch all dims data from /dims endpoint (both standard and custom in one call)
  Future<Map<String, List<dynamic>>> fetchAllDims({int retries = 2}) async {
    int attempt = 0;
    
    while (attempt <= retries) {
      try {
        attempt++;
        print('🔄 Fetching all dims... (attempt $attempt/${retries + 1})');
        
        // Use extended timeout for this large data request
        final response = await _dio.get(
          'dims',
          options: Options(
            receiveTimeout: const Duration(minutes: 5),
            sendTimeout: const Duration(minutes: 5),
            validateStatus: (status) => status! < 500, // Accept any status < 500
          ),
        );
        
        print('✓ Dims response received: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          if (response.data is Map) {
            Map<String, List<dynamic>> result = {};
            
            // Extract standard_dims
            if (response.data['standard_dims'] is List) {
              result['standard_dims'] = List<dynamic>.from(response.data['standard_dims']);
              print('✓ Extracted ${result['standard_dims']!.length} standard dims');
            } else {
              print('⚠ standard_dims not found or not a list');
              result['standard_dims'] = [];
            }
            
            // Extract custom_dims
            if (response.data['custom_dims'] is List) {
              result['custom_dims'] = List<dynamic>.from(response.data['custom_dims']);
              print('✓ Extracted ${result['custom_dims']!.length} custom dims');
            } else {
              print('⚠ custom_dims not found or not a list');
              result['custom_dims'] = [];
            }
            
            return result;
          }
          throw Exception('Unexpected response format: ${response.data.runtimeType}');
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } on DioException catch (e) {
        print('❌ Dims DioException (attempt $attempt): ${e.type}');
        print('❌ Error message: ${e.message}');
        
        // If this is the last attempt, throw the error
        if (attempt > retries) {
          if (e.type == DioExceptionType.connectionTimeout) {
            throw Exception('Connection timeout after $attempt attempts. Please check your internet connection.');
          } else if (e.type == DioExceptionType.receiveTimeout) {
            throw Exception('Server timeout after $attempt attempts. Please try again later.');
          } else if (e.type == DioExceptionType.sendTimeout) {
            throw Exception('Request timeout after $attempt attempts. Please try again.');
          } else if (e.type == DioExceptionType.connectionError) {
            throw Exception('Connection error. Please check your internet connection.');
          } else {
            throw Exception('Network error: ${e.message}');
          }
        }
        
        // Wait before retrying
        print('⏳ Waiting 2 seconds before retry...');
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('❌ Dims general error (attempt $attempt): $e');
        
        if (attempt > retries) {
          throw Exception('Error: $e');
        }
        
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    throw Exception('Failed to fetch dims after ${retries + 1} attempts');
  }

  // Fetch dims data from /dims/{type} endpoint (standard or custom) - DEPRECATED, use fetchAllDims instead
  Future<List<dynamic>> fetchDims(String type) async {
    try {
      print('Fetching dims: $type');
      final response = await _dio.get('dims/$type');
      
      print('Dims response status: ${response.statusCode}');
      print('Dims response data: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<dynamic>.from(response.data);
        } else if (response.data is Map && response.data['data'] is List) {
          return List<dynamic>.from(response.data['data']);
        }
        throw Exception('Unexpected response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Dims DioException: ${e.type}');
      print('Dims error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Dims general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Search across dims databases
  Future<List<dynamic>> searchDims(String query) async {
    try {
      print('Searching dims: $query');
      final response = await _dio.get('dims/search', queryParameters: {'query': query});
      
      print('Dims search response status: ${response.statusCode}');
      print('Dims search response data: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<dynamic>.from(response.data);
        } else if (response.data is Map) {
          if (response.data['results'] != null && response.data['results'] is List) {
            return List<dynamic>.from(response.data['results']);
          }
          // Combine all results from different tables
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
      print('Dims search DioException: ${e.type}');
      print('Dims search error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Dims search general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Fetch available projects list
  Future<List<String>> fetchProjects() async {
    try {
      print('Fetching projects list...');
      final response = await _dio.get('process/projects');
      
      print('Projects response status: ${response.statusCode}');
      print('Projects response data: ${response.data}');
      print('Projects response type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<String>.from(response.data);
        } else if (response.data is Map) {
          // If backend returns {projects: [...]} format
          if (response.data['projects'] != null && response.data['projects'] is List) {
            return List<String>.from(response.data['projects']);
          }
          // If backend returns map keys as project names
          return response.data.keys.map((k) => k.toString()).toList();
        }
        throw Exception('Unexpected response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Projects DioException: ${e.type}');
      print('Projects error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Projects general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Fetch project data for a specific project
  Future<Map<String, List<dynamic>>> fetchProjectData(String projectName) async {
    try {
      print('Fetching project data for: $projectName');
      final response = await _dio.get(
        'process/$projectName',
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );
      
      print('Project data response status: ${response.statusCode}');
      print('Project data response type: ${response.data.runtimeType}');
      print('Project data response: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data is Map) {
          Map<String, List<dynamic>> result = {};
          
          // Extract the nested "data" object
          final dataMap = response.data['data'];
          
          if (dataMap == null) {
            print('⚠ No "data" key found in response');
            return result;
          }
          
          if (dataMap is! Map) {
            print('⚠ "data" is not a Map, it is ${dataMap.runtimeType}');
            return result;
          }
          
          print('Data map keys: ${dataMap.keys.toList()}');
          
          // Convert all table data to proper format
          dataMap.forEach((key, value) {
            print('Processing key: "$key", value type: ${value.runtimeType}');
            if (value is List) {
              result[key] = List<dynamic>.from(value);
              print('✓ Extracted ${result[key]!.length} items from $key');
            } else {
              print('⚠ Skipping "$key" - value is not a List, it is ${value.runtimeType}');
            }
          });
          
          print('Final result keys: ${result.keys.toList()}');
          return result;
        }
        throw Exception('Unexpected response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Project data DioException: ${e.type}');
      print('Project data error message: ${e.message}');
      
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server timeout. Please try again later.');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('Project data general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Search process data
  Future<List<dynamic>> searchProcess(String query) async {
    try {
      print('Searching process: $query');
      final response = await _dio.get('process/search', queryParameters: {'query': query});
      
      print('Process search response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<dynamic>.from(response.data);
        } else if (response.data is Map) {
          // If backend returns {results: [...]} format
          if (response.data['results'] != null && response.data['results'] is List) {
            return List<dynamic>.from(response.data['results']);
          }
          // Combine all results from different tables
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
      print('Process search DioException: ${e.type}');
      print('Process search error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Process search general error: $e');
      throw Exception('Error: $e');
    }
  }
}