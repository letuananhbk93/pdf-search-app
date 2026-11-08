import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

class TimelineException implements Exception {
  TimelineException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Calls the TIMELINE endpoints. Google Drive and its API key are only used on the server.
class TimelineService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pdf-search-backend-tlcvietnam-282948b11d32.herokuapp.com/',  // Production backend
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  Future<Map<String, dynamic>> fetchYears() => _get('timeline/years');

  Future<Map<String, dynamic>> fetchPos(int year) => _get('timeline/years/$year/pos');

  Future<Map<String, dynamic>> fetchSuppliers(String poKey) => _get('timeline/pos/$poKey/suppliers');

  Future<Map<String, dynamic>> fetchSupplier(int supplierId) => _get('timeline/suppliers/$supplierId');

  Future<Map<String, dynamic>> fetchStatus() => _get('timeline/status');

  /// Starts the Drive sync on the server and returns at once.
  Future<Map<String, dynamic>> startReload() => _guard(() async {
        final response = await _dio.post('timeline/reload');
        return Map<String, dynamic>.from(response.data as Map);
      });

  Future<Map<String, dynamic>> previewUpload(PlatformFile file) => _uploadFile('timeline/upload-preview', file);

  Future<Map<String, dynamic>> saveUpload(PlatformFile file, {required bool allowOlder}) =>
      _uploadFile('timeline/upload', file, allowOlder: allowOlder);

  Future<Map<String, dynamic>> _get(String path) => _guard(() async {
        final response = await _dio.get(path);
        return Map<String, dynamic>.from(response.data as Map);
      });

  Future<Map<String, dynamic>> _uploadFile(String path, PlatformFile file, {bool? allowOlder}) => _guard(() async {
        final bytes = file.bytes;
        if (bytes == null) {
          throw TimelineException('The file could not be read. Please pick it again.');
        }
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: file.name),
          if (allowOlder != null) 'allow_older': allowOlder.toString(),
        });
        final response = await _dio.post(path, data: form);
        return Map<String, dynamic>.from(response.data as Map);
      });

  /// Turns Dio errors into a message the screens can show (FastAPI puts it in "detail").
  Future<Map<String, dynamic>> _guard(Future<Map<String, dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail'] : null;
      throw TimelineException(detail?.toString() ?? 'Network error: ${e.message}');
    }
  }
}
