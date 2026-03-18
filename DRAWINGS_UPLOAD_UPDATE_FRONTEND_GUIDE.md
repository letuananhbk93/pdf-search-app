# Drawings Upload & Update - Frontend Implementation Guide

## 🎯 Overview
New functionality for uploading single/multiple drawings and updating (replacing) existing drawings with new files.

> **⚠️ Web Compatibility Fixed**: Updated all file handling code to use `bytes` property instead of `path` for Flutter web compatibility. Added `withData: true` to file picker for web platform support.

## 📋 User Flow

### Upload Drawing(s)
```
Drawings Screen → Hamburger Menu → "Upload Drawings" 
→ File Picker (PDF files) → Select 1 or more PDFs → "Upload" Button
→ Upload to backend → Show success/error results
```

### Update (Replace) Drawing
```
Drawings Screen → Hamburger Menu → "Update Drawings"
→ File Picker (single PDF) → Search existing drawing by name
→ Select drawing to replace → Confirm replacement
→ Upload new file → Show success/error results
```

## 🔌 API Endpoints

### 1. Upload Drawings - `POST /drawings/upload`

**Request:** `multipart/form-data`
```dart
// FormData with multiple PDF files (Web Compatible)
var formData = FormData();
for (PlatformFile file in filePickerResult.files) {
  if (file.bytes != null) { // Web
    formData.files.add(MapEntry(
      'files', 
      MultipartFile.fromBytes(file.bytes!, filename: file.name)
    ));
  } else if (file.path != null) { // Mobile/Desktop
    formData.files.add(MapEntry(
      'files', 
      await MultipartFile.fromFile(file.path!, filename: file.name)
    ));
  }
}
```

**Response:**
```json
{
  "success_count": 2,
  "error_count": 1,
  "uploaded": [
    {
      "id": 123,
      "filename": "drawing1.pdf",
      "url": "https://storage.googleapis.com/...",
      "thumbnail_url": "https://storage.googleapis.com/thumbnails/drawing1.png",
      "message": "Uploaded successfully"
    }
  ],
  "errors": [
    {
      "filename": "duplicate.pdf", 
      "error": "Drawing already exists (id=45). Use /drawings/update/45 to replace it."
    }
  ]
}
```

### 2. Search Drawings - `GET /drawings/search`

**Request:** 
```dart
final response = await dio.get('/drawings/search', queryParameters: {
  'query': searchText,
  'limit': 10
});
```

**Response:**
```json
{
  "results": [
    {
      "id": 123,
      "filename": "floor_plan_v1.pdf",
      "url": "https://storage.googleapis.com/...",
      "thumbnail_url": "https://storage.googleapis.com/thumbnails/floor_plan_v1.png"
    }
  ],
  "total": 5
}
```

### 3. Update Drawing - `POST /drawings/update/{drawing_id}`

**Request:** `multipart/form-data`
```dart
// Web compatible file upload
MultipartFile multipartFile;
if (platformFile.bytes != null) { // Web
  multipartFile = MultipartFile.fromBytes(platformFile.bytes!, filename: platformFile.name);
} else if (platformFile.path != null) { // Mobile/Desktop
  multipartFile = await MultipartFile.fromFile(platformFile.path!, filename: platformFile.name);
}

var formData = FormData.fromMap({
  'file': multipartFile
});
final response = await dio.post('/drawings/update/$drawingId', data: formData);
```

**Response:**
```json
{
  "success": true,
  "message": "Drawing replaced: 'old_name.pdf' → 'new_name.pdf'",
  "id": 123,
  "filename": "new_name.pdf",
  "url": "https://storage.googleapis.com/...",
  "thumbnail_url": "https://storage.googleapis.com/thumbnails/new_name.png"
}
```

## 🛠 Flutter Implementation Tips

### 1. File Picker for PDFs (Web Compatible)
```dart
// For upload (multiple files)
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['pdf'],
  allowMultiple: true,
  withData: true, // Important for web - loads bytes
);

// For update (single file)
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['pdf'],
  allowMultiple: false,
  withData: true, // Important for web - loads bytes
);

// Usage example:
if (result != null && result.files.isNotEmpty) {
  for (PlatformFile file in result.files) {
    print('File: ${file.name}');
    print('Size: ${file.size} bytes');
    print('Has bytes: ${file.bytes != null}'); // Web
    print('Has path: ${file.path != null}');   // Mobile/Desktop
  }
}
```

### 2. Upload Service Class (Web Compatible)
```dart
import 'package:file_picker/file_picker.dart';

class DrawingsService {
  final Dio dio = Dio();
  
  Future<Map<String, dynamic>> uploadDrawings(FilePickerResult result) async {
    var formData = FormData();
    
    for (PlatformFile file in result.files) {
      if (file.bytes != null) { // Web compatibility
        formData.files.add(MapEntry(
          'files', 
          MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
          )
        ));
      } else if (file.path != null) { // Mobile/Desktop
        formData.files.add(MapEntry(
          'files', 
          await MultipartFile.fromFile(file.path!, filename: file.name)
        ));
      }
    }
    
    final response = await dio.post('/drawings/upload', data: formData);
    return response.data;
  }
  
  Future<List<DrawingSearchResult>> searchDrawings(String query) async {
    final response = await dio.get('/drawings/search', queryParameters: {
      'query': query,
      'limit': 20
    });
    
    return (response.data['results'] as List)
        .map((item) => DrawingSearchResult.fromJson(item))
        .toList();
  }
  
  Future<Map<String, dynamic>> updateDrawing(int drawingId, PlatformFile newPdfFile) async {
    late MultipartFile multipartFile;
    
    if (newPdfFile.bytes != null) { // Web compatibility
      multipartFile = MultipartFile.fromBytes(
        newPdfFile.bytes!,
        filename: newPdfFile.name,
      );
    } else if (newPdfFile.path != null) { // Mobile/Desktop
      multipartFile = await MultipartFile.fromFile(
        newPdfFile.path!, 
        filename: newPdfFile.name
      );
    } else {
      throw Exception('File has no bytes or path available');
    }
    
    var formData = FormData.fromMap({
      'file': multipartFile
    });
    
    final response = await dio.post('/drawings/update/$drawingId', data: formData);
    return response.data;
  }
}
```

### 3. Data Models
```dart
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
}

class UploadResult {
  final int successCount;
  final int errorCount;
  final List<UploadedDrawing> uploaded;
  final List<UploadError> errors;
  
  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      successCount: json['success_count'],
      errorCount: json['error_count'],
      uploaded: (json['uploaded'] as List)
          .map((item) => UploadedDrawing.fromJson(item))
          .toList(),
      errors: (json['errors'] as List)
          .map((item) => UploadError.fromJson(item))
          .toList(),
    );
  }
}
```

### 4. UI Screens Structure

#### Upload Drawings Screen
```dart
class UploadDrawingsScreen extends StatefulWidget {
  // File picker → Multiple PDF selection → Upload button → Progress indicator → Results
}
```

#### Update Drawing Screen  
```dart
class UpdateDrawingScreen extends StatefulWidget {
  // Step 1: File picker (new PDF)
  // Step 2: Search field for existing drawings
  // Step 3: List of search results with thumbnails
  // Step 4: Confirm replacement dialog
  // Step 5: Upload & show results
}
```

## 🎨 UI/UX Recommendations

### Upload Screen
- **File Picker Button**: "Select PDF Files" with multiple file icon
- **Selected Files List**: Show selected PDF names with remove option
- **Upload Button**: Disabled until files selected, shows progress during upload
- **Results Section**: Success/error messages with counts

### Update Screen
- **New File Section**: "Select New PDF" file picker
- **Search Section**: Text input "Search existing drawing to replace..."
- **Search Results**: List with thumbnails, file names, and "Replace" buttons
- **Confirmation Dialog**: "Replace [old_name] with [new_name]?" with preview

### Progress Indicators
```dart
// Upload progress
LinearProgressIndicator(
  value: uploadProgress, // 0.0 to 1.0 per file
)

// Search loading
CircularProgressIndicator()
```

### Error Handling
```dart
// Show snackbar for errors
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Upload failed: ${error.message}'),
    backgroundColor: Colors.red,
  ),
);

// Success message
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('${successCount} drawings uploaded successfully!'),
    backgroundColor: Colors.green,
  ),
);
```

## 🔄 Integration with Existing Drawings List

After successful upload/update, refresh the main drawings list:
```dart
// Trigger refresh in parent screen
Navigator.pop(context, true); // Return success flag
```

In main drawings screen:
```dart
// Handle return from upload/update screens
final result = await Navigator.push(context, /* upload screen */);
if (result == true) {
  _refreshDrawingsList(); // Reload drawings from API
}
```

## 🚨 Error Scenarios to Handle

1. **Network Errors**: No internet connection
2. **File Size**: PDFs too large (show size limits)
3. **File Type**: Non-PDF files selected
4. **Server Errors**: Backend issues (500 errors)
5. **Duplicates**: Drawing already exists (in upload mode)
6. **Not Found**: Drawing to update doesn't exist
7. **Permission**: File access denied

### Web Platform Specific Errors

**Error: "On web 'path' is unavailable"**
- **Cause**: Using `file.path` on web platform
- **Solution**: Use `file.bytes` instead and add `withData: true` to FilePicker
- **Fix**: See updated code examples above with `MultipartFile.fromBytes()`

## 📱 Navigation Structure

```
Main Drawer/Hamburger Menu:
├── Upload Drawings → UploadDrawingsScreen
├── Update Drawings → UpdateDrawingScreen
└── (existing menu items...)
```

## ⚡ Performance Tips

1. **Thumbnail Loading**: Use `CachedNetworkImage` for thumbnails in search results
2. **File Size Check**: Validate PDF size before upload (recommend < 50MB)
3. **Progress Feedback**: Show upload progress for large files
4. **Debounced Search**: Wait 300ms after user stops typing before searching
5. **Pagination**: Load search results in chunks if many matches

## 🔧 Backend Features Included

- ✅ **Duplicate Detection**: Prevents duplicate filenames in upload
- ✅ **Text Extraction**: Full-text search capability maintained  
- ✅ **Thumbnail Generation**: Automatic PNG thumbnails created
- ✅ **GCS Storage**: PDFs and thumbnails stored in Google Cloud
- ✅ **Search Index**: Whoosh full-text index updated automatically
- ✅ **Replace Logic**: Complete replacement preserving drawing ID
- ✅ **Error Handling**: Comprehensive error responses