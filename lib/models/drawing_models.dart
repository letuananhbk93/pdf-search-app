// Models for drawings upload and update functionality

class DrawingSearchResult {
  final int id;
  final String filename;
  final String url;
  final String? thumbnailUrl;
  
  DrawingSearchResult({
    required this.id,
    required this.filename,
    required this.url,
    this.thumbnailUrl,
  });
  
  factory DrawingSearchResult.fromJson(Map<String, dynamic> json) {
    return DrawingSearchResult(
      id: json['id'],
      filename: json['filename'],
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'url': url,
      'thumbnail_url': thumbnailUrl,
    };
  }
}

class UploadedDrawing {
  final int id;
  final String filename;
  final String url;
  final String? thumbnailUrl;
  final String message;
  
  UploadedDrawing({
    required this.id,
    required this.filename,
    required this.url,
    this.thumbnailUrl,
    required this.message,
  });
  
  factory UploadedDrawing.fromJson(Map<String, dynamic> json) {
    return UploadedDrawing(
      id: json['id'],
      filename: json['filename'],
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
      message: json['message'] ?? 'Uploaded successfully',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'message': message,
    };
  }
}

class UploadError {
  final String filename;
  final String error;
  
  UploadError({
    required this.filename,
    required this.error,
  });
  
  factory UploadError.fromJson(Map<String, dynamic> json) {
    return UploadError(
      filename: json['filename'],
      error: json['error'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'error': error,
    };
  }
}

class UploadResult {
  final int successCount;
  final int errorCount;
  final List<UploadedDrawing> uploaded;
  final List<UploadError> errors;
  
  UploadResult({
    required this.successCount,
    required this.errorCount,
    required this.uploaded,
    required this.errors,
  });
  
  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      successCount: json['success_count'] ?? 0,
      errorCount: json['error_count'] ?? 0,
      uploaded: (json['uploaded'] as List? ?? [])
          .map((item) => UploadedDrawing.fromJson(item))
          .toList(),
      errors: (json['errors'] as List? ?? [])
          .map((item) => UploadError.fromJson(item))
          .toList(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success_count': successCount,
      'error_count': errorCount,
      'uploaded': uploaded.map((item) => item.toJson()).toList(),
      'errors': errors.map((item) => item.toJson()).toList(),
    };
  }
}

class UpdateResult {
  final bool success;
  final String message;
  final int id;
  final String filename;
  final String url;
  final String? thumbnailUrl;
  
  UpdateResult({
    required this.success,
    required this.message,
    required this.id,
    required this.filename,
    required this.url,
    this.thumbnailUrl,
  });
  
  factory UpdateResult.fromJson(Map<String, dynamic> json) {
    return UpdateResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      id: json['id'],
      filename: json['filename'],
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'id': id,
      'filename': filename,
      'url': url,
      'thumbnail_url': thumbnailUrl,
    };
  }
}