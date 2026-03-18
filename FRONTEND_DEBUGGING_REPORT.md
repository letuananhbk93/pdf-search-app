# Frontend Drawings Upload/Update Error Analysis & Fixes

## 🚨 Errors Encountered

### 1. Web Compatibility Error (✅ FIXED)
**Error:** `"On web 'path' is unavailable"`
**Cause:** Frontend was using `file.path` property which doesn't exist on web platforms
**Fix Applied:**
- Updated FilePicker to use `withData: true`
- Changed from `File` objects to `PlatformFile` objects
- Use `file.bytes` for web, `file.path` for mobile/desktop
- Updated `MultipartFile.fromBytes()` for web compatibility

### 2. Search Endpoint Error (✅ FIXED)
**Error:** `404 - drawings/search not found`
**Cause:** Frontend was trying to use `'drawings/search'` endpoint that doesn't exist
**Fix Applied:**
- Changed search endpoint from `'drawings/search'` → `'search'`
- This reuses the existing working search endpoint that already handles PDF/drawings

### 3. Upload/Update Endpoints Error (❓ NEEDS BACKEND VERIFICATION)
**Current Error:** `404 - upload/update endpoints not found`
**Attempts Made:**
1. `'drawings/upload'` → 404 error
2. `'upload'` → 404 error  
3. `'upload-drawings'` → Current attempt (needs testing)

## 🔧 Current Frontend Implementation

### API Endpoints Used:
```dart
// Search (✅ Working)
GET /search?query={searchTerm}

// Upload (❓ Needs verification)
POST /upload-drawings
Content-Type: multipart/form-data
Body: files[] (multiple PDF files)

// Update (❓ Needs verification) 
POST /update-drawing/{drawing_id}
Content-Type: multipart/form-data
Body: file (single PDF file)
```

### Expected Response Formats:

#### Upload Response:
```json
{
  "success_count": 2,
  "error_count": 1,
  "uploaded": [
    {
      "id": 123,
      "filename": "drawing1.pdf",
      "url": "https://storage.googleapis.com/...",
      "thumbnail_url": "https://storage.googleapis.com/...",
      "message": "Uploaded successfully"
    }
  ],
  "errors": [
    {
      "filename": "duplicate.pdf", 
      "error": "Drawing already exists"
    }
  ]
}
```

#### Update Response:
```json
{
  "success": true,
  "message": "Drawing replaced: 'old_name.pdf' → 'new_name.pdf'",
  "id": 123,
  "filename": "new_name.pdf",
  "url": "https://storage.googleapis.com/...",
  "thumbnail_url": "https://storage.googleapis.com/..."
}
```

#### Search Response (Already Working):
```json
[
  {
    "id": 123,
    "filename": "floor_plan_v1.pdf",
    "url": "https://storage.googleapis.com/...",
    "thumbnail_url": "https://storage.googleapis.com/..."
  }
]
```

## 🎯 Backend Requirements

### What Backend Needs to Implement:

1. **Upload Endpoint:**
   - **Route:** `POST /upload-drawings` (or tell us the correct name)
   - **Function:** Accept multiple PDF files and store them
   - **Response:** Success/error counts with details

2. **Update Endpoint:**
   - **Route:** `POST /update-drawing/{drawing_id}` (or tell us the correct name)
   - **Function:** Replace existing drawing with new PDF file
   - **Response:** Success confirmation with new file details

3. **Search Endpoint:** ✅ Already working!
   - **Route:** `GET /search?query={searchTerm}`
   - **Function:** Search existing drawings by filename/content
   - **Response:** Array of matching drawings

## 🔍 Questions for Backend Team

1. **What are the correct endpoint names?**
   - Upload multiple drawings: `_________________`
   - Update/replace single drawing: `_________________`

2. **Are these endpoints already implemented and deployed to Heroku?**

3. **Do the expected request/response formats match your implementation?**

4. **Alternative endpoint names to try:**
   - `POST /upload-pdfs`
   - `POST /drawings/upload`
   - `POST /pdf/upload`
   - `PUT /drawings/{id}`
   - `PATCH /drawings/{id}`

## 🛠 How to Test Endpoints

You can test if endpoints exist by checking these URLs:

```bash
# Test upload endpoint exists
curl -X POST https://pdf-search-backend-tlcvietnam-282948b11d32.herokuapp.com/upload-drawings

# Test update endpoint exists  
curl -X POST https://pdf-search-backend-tlcvietnam-282948b11d32.herokuapp.com/update-drawing/123

# Working search endpoint (for reference)
curl "https://pdf-search-backend-tlcvietnam-282948b11d32.herokuapp.com/search?query=test"
```

## 🔄 Next Steps

1. **Backend team confirms/provides correct endpoint names**
2. **Frontend updates endpoint names if needed**
3. **Test upload functionality**
4. **Test update functionality**
5. **Verify response format compatibility**

## 📝 Code Changes Made

### Files Modified:
- `lib/services/api_service.dart` - Added upload/update methods
- `lib/models/drawing_models.dart` - Added data models
- `lib/screens/upload_drawings_screen.dart` - New upload UI
- `lib/screens/update_drawing_screen.dart` - New update UI  
- `lib/screens/search_screen.dart` - Added hamburger menu
- `pubspec.yaml` - Removed unnecessary `path` dependency

### Current Status:
- ✅ Web compatibility fixed
- ✅ Search functionality working
- ❓ Upload/Update endpoints need backend verification