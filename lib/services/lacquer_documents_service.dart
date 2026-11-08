import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/lacquer_document.dart';

const _baseUrl =
    'https://pdf-search-backend-tlcvietnam-282948b11d32.herokuapp.com/';

const lacquerDocumentExtensions = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
];

/// Returns the server's `detail` text for a failed request, or a generic message.
///
/// The PDF download uses `ResponseType.bytes`, so the error body can arrive as
/// raw bytes or a string instead of a decoded map. All three shapes are handled.
String errorMessage(Object error) {
  if (error is DioException) {
    final detail = _detailFrom(error.response?.data);
    if (detail != null) return detail;
    return error.message ?? 'Network error. Please try again.';
  }
  return error.toString();
}

String? _detailFrom(Object? data) {
  final body = data is List<int>
      ? utf8.decode(data, allowMalformed: true)
      : data;
  final json = body is String ? _tryDecode(body) : body;
  if (json is Map && json['detail'] is String) return json['detail'] as String;
  return null;
}

Object? _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

/// A saved About Lacquer presentation: the PDF bytes and the name shown in the title bar.
class AboutPresentation {
  const AboutPresentation({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;
}

/// Result of a bulk delete: the ids that were removed, and the ids that failed with the reason.
class DeleteResult {
  const DeleteResult({required this.deleted, required this.failed});

  final List<String> deleted;
  final Map<String, String> failed;
}

class LacquerDocumentsService {
  LacquerDocumentsService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

  final Dio _dio;

  Future<List<LacquerDocument>> listDocuments() async {
    final response = await _dio.get<List<dynamic>>('lacquer-documents');
    return (response.data ?? [])
        .map((item) => LacquerDocument.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LacquerDocument> uploadDocument(
    PlatformFile file, {
    void Function(double progress)? onProgress,
  }) async {
    final multipartFile = file.bytes != null
        ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
        : await MultipartFile.fromFile(file.path!, filename: file.name);
    final response = await _dio.post<Map<String, dynamic>>(
      'lacquer-documents',
      data: FormData.fromMap({'file': multipartFile}),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    return LacquerDocument.fromJson(response.data!);
  }

  Future<DeleteResult> deleteDocuments(List<String> ids) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'lacquer-documents/bulk-delete',
      data: {'ids': ids.map((id) => int.tryParse(id) ?? id).toList()},
    );
    final json = response.data ?? {};
    final deleted = (json['deleted'] as List? ?? [])
        .map((id) => id.toString())
        .toList();
    final failed = <String, String>{
      for (final item in (json['failed'] as List? ?? []))
        (item as Map<String, dynamic>)['id'].toString():
            item['detail'] as String? ?? 'Delete failed',
    };
    return DeleteResult(deleted: deleted, failed: failed);
  }

  /// The saved About Lacquer presentation, or null if none has been chosen yet.
  Future<AboutPresentation?> getAboutLacquerPdf() async {
    try {
      final response = await _dio.get<List<int>>(
        'about-lacquer/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      // The title is sent URL-encoded so non-ASCII names fit in a header.
      final encodedTitle = response.headers.value('x-presentation-title');
      return AboutPresentation(
        bytes: Uint8List.fromList(response.data!),
        title: encodedTitle == null ? '' : Uri.decodeComponent(encodedTitle),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> saveAboutLacquerPdf(AboutPresentation presentation) async {
    await _dio.put(
      'about-lacquer/pdf',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          presentation.bytes,
          filename: 'about_lacquer.pdf',
        ),
        'title': presentation.title,
      }),
    );
  }

  Future<Uint8List> downloadPdf(String id) async {
    final response = await _dio.get<List<int>>(
      'lacquer-documents/$id/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: lacquerDocumentExtensions,
      withData: kIsWeb,
    );
    return result?.files.single;
  }
}
