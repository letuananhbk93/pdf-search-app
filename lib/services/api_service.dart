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

  // Update color item
  Future<void> updateColor(
    String tableName,
    int colorId,
    Map<String, dynamic> updatedData,
    String changedBy,
  ) async {
    try {
      print('🔄 Updating color...');
      print('📋 Table name: $tableName');
      print('🆔 Color ID: $colorId');
      print('👤 Changed by: $changedBy');
      print('📦 Updated data: $updatedData');
      
      String endpoint = 'colors/$tableName/$colorId';
      print('🌐 Full URL: ${_dio.options.baseUrl}$endpoint?changed_by=$changedBy');
      
      final response = await _dio.put(
        endpoint,
        queryParameters: {'changed_by': changedBy},
        data: updatedData,
      );
      
      print('✅ Update response status: ${response.statusCode}');
      print('📄 Update response data: ${response.data}');
      
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode} - ${response.data}');
      }
    } on DioException catch (e) {
      print('❌ Update DioException: ${e.type}');
      print('❌ Update error message: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      print('❌ Request URL: ${e.requestOptions.uri}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('❌ Update general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Get color history
  Future<List<Map<String, dynamic>>> getColorHistory(
    String tableName,
    int colorId,
  ) async {
    try {
      print('Getting color history: $tableName/$colorId');
      final response = await _dio.get('colors/$tableName/$colorId/history');
      
      print('History response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        }
        throw Exception('Unexpected history response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('History DioException: ${e.type}');
      print('History error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('History general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Get all colors history across all tables with filters and pagination
  Future<Map<String, dynamic>> getAllColorsHistory({
    int limit = 50,
    int offset = 0,
    String? tableFilter,
    String? actionFilter,
    String? changedByFilter,
  }) async {
    try {
      print('Getting all colors history...');
      
      Map<String, dynamic> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      if (tableFilter != null && tableFilter.isNotEmpty && tableFilter != 'all') {
        queryParams['table_filter'] = tableFilter;
      }
      
      if (actionFilter != null && actionFilter.isNotEmpty && actionFilter != 'all') {
        queryParams['action_filter'] = actionFilter;
      }
      
      if (changedByFilter != null && changedByFilter.isNotEmpty) {
        queryParams['changed_by_filter'] = changedByFilter;
      }
      
      print('Query params: $queryParams');
      
      final response = await _dio.get(
        'colors/history/all',
        queryParameters: queryParams,
      );
      
      print('All history response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data);
        }
        throw Exception('Unexpected all history response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('All history DioException: ${e.type}');
      print('All history error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('All history general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Get last update information
  Future<Map<String, dynamic>> getLastUpdateInfo([String? category]) async {
    try {
      print('Fetching last update info for category: ${category ?? 'general'}');
      
      final queryParams = <String, dynamic>{};
      if (category != null) {
        queryParams['category'] = category;
      }
      
      final url = 'last-update${queryParams.isNotEmpty ? '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&') : ''}';
      print('API URL: ${_dio.options.baseUrl}$url');
      
      final response = await _dio.get('last-update', queryParameters: queryParams);
      
      print('Last update response status: ${response.statusCode}');
      print('Last update response data: ${response.data}');
      print('Last update response data type: ${response.data.runtimeType}');
      if (response.data is Map) {
        print('Response keys: ${response.data.keys.toList()}');
        print('last_update field: ${response.data['last_update']}');
      }
      
      if (response.statusCode == 200) {
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data);
        }
        throw Exception('Unexpected last update response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Last update DioException: ${e.type}');
      print('Last update error message: ${e.message}');
      print('Last update response: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Last update general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Get all production plan projects
  Future<List<String>> getProductionPlanProjects() async {
    try {
      print('Fetching production plan projects');
      final response = await _dio.get('production-plan/projects');
      
      print('Production plan projects response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.data is Map && response.data['projects'] is List) {
          return List<String>.from(response.data['projects']);
        } else if (response.data is List) {
          return List<String>.from(response.data);
        }
        throw Exception('Unexpected production plan projects response format');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Production plan projects DioException: ${e.type}');
      print('Production plan projects error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Production plan projects general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Get Gantt data for a specific project with view mode
  Future<Map<String, dynamic>> getGanttData(String poNumber, {String viewMode = 'week'}) async {
    try {
      print('Fetching Gantt data for: $poNumber with view mode: $viewMode');
      final response = await _dio.get('production-plan/$poNumber/gantt?view_mode=$viewMode');
      
      print('Gantt data response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data);
        }
        throw Exception('Unexpected Gantt data response format');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Gantt data DioException: ${e.type}');
      print('Gantt data error message: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Gantt data general error: $e');
      throw Exception('Error: $e');
    }
  }

  // Get view modes information
  Future<Map<String, dynamic>?> getViewModes() async {
    try {
      final response = await _dio.get('production-plan/view-modes');
      
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching view modes: $e');
      return null;
    }
  }

  // Get project phases
  Future<List<Map<String, dynamic>>> getProjectPhases(String poNumber) async {
    try {
      print('Fetching project phases for: $poNumber');
      final response = await _dio.get('production-plan/$poNumber');
      
      print('Project phases response status: ${response.statusCode}');
      print('Project phases response data: ${response.data}');
      
      if (response.statusCode == 200) {
        print('Raw response data: ${response.data}');
        if (response.data is Map && response.data['phases'] is List) {
          final phases = List<Map<String, dynamic>>.from(response.data['phases']);
          print('Successfully parsed ${phases.length} phases from phases key');
          for (int i = 0; i < phases.length && i < 3; i++) {
            print('Phase $i sample: ${phases[i]}');
          }
          return phases;
        } else if (response.data is List) {
          final phases = List<Map<String, dynamic>>.from(response.data);
          print('Successfully parsed ${phases.length} phases from direct list');
          for (int i = 0; i < phases.length && i < 3; i++) {
            print('Phase $i sample: ${phases[i]}');
          }
          return phases;
        } else if (response.data is Map) {
          print('Response is a map, looking for phases data...');
          // Try to find phases in any nested structure
          final data = response.data as Map<String, dynamic>;
          for (var key in data.keys) {
            if (data[key] is List) {
              final phases = List<Map<String, dynamic>>.from(data[key]);
              print('Found ${phases.length} phases under key: $key');
              return phases;
            }
          }
          // If no list found, return empty list
          print('No phases list found in response');
          return [];
        }
        throw Exception('Unexpected project phases response format: ${response.data.runtimeType}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Project phases DioException: ${e.type}');
      print('Project phases error message: ${e.message}');
      print('Project phases response: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Project phases general error: $e');
      throw Exception('Error: $e');
    }
  }
}