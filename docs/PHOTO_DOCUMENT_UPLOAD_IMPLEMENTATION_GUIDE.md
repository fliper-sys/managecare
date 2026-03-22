# Photo & Document Upload Implementation Guide

## Overview
This guide documents the photo and document upload pattern used across the Manage Care application, specifically for:
- Business profile photos
- Real Estate property images
- Property documents (PDFs, Word docs, spreadsheets, images)

## Pattern Implementation: Business Photo Upload

### 1. **File Selection & Compression**
```dart
// Source: business_settings_screen.dart line 438
Future<void> _pickAndUploadBusinessPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final filename = xfile.name;
```

**Key Points:**
- Uses `ImagePicker` for gallery/camera selection
- `imageQuality: 85` reduces file size while maintaining quality
- Image bytes read immediately for web compatibility

### 2. **Optimistic UI Update (Before Upload)**
```dart
    setState(() {
        _isUploadingPhoto = true;
        _pendingPhotoBytes = bytes;      // Store for retry
        _pendingPhotoFilename = filename; // Store for retry
    });
```

**Key Points:**
- Shows loading state while uploading
- Stores pending bytes/filename for retry logic
- Allows user to retry if upload fails

### 3. **Backend Upload Using EmailService**
```dart
    final url = await EmailService().uploadBytes(bytes, filename);
```

**EmailService Methods:**
- `uploadBytes(List<int> bytes, String filename)` - For web compatibility
- `uploadFile(File file)` - For mobile (IO) compatibility
- Returns: URL of uploaded file or null if failed
- **Security:** Files validated on backend before storage

### 4. **Cache-Busting Strategy**
```dart
    if (url != null) {
        final cachebusted = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
        setState(() => _photoUrl = cachebusted);
```

**Why Cache-Busting:**
- Browser/CDN caches by URL
- Adding timestamp query parameter forces fresh fetch
- Shows updated image immediately to user
- Prevents stale image display

### 5. **Persistence to Backend**
```dart
    try {
        final businessProvider = context.read<BusinessProvider>();
        final business = businessProvider.currentBusiness;
        if (business != null) {
            final updated = business.copyWith(photoUrl: cachebusted);
            await businessProvider.updateBusiness(updated);
        }
    } catch (e) {
        debugPrint('Persist business photo error: $e');
    }
```

**Key Points:**
- Updates BusinessProvider state (Firestore update)
- Non-blocking: failure doesn't affect photo display
- Photo already visible in UI (optimistic update)

### 6. **Cache Eviction**
```dart
    await _evictAndRemoveCache(url);
    await _evictAndRemoveCache(cachebusted);
```

**Cache Management:**
- Clears CachedNetworkImage cache
- Removes from device storage
- Ensures fresh image on next load
- Necessary for profile photos and business logos

### 7. **Retry Logic**
```dart
    Future<void> _retryUploadPhoto() async {
        if (_pendingPhotoBytes == null || _pendingPhotoFilename == null) return;
        try {
            setState(() => _isUploadingPhoto = true);
            final url = await EmailService().uploadBytes(
                _pendingPhotoBytes!, 
                _pendingPhotoFilename!
            );
            // ... same persistence and cache logic
        }
    }
```

**Key Points:**
- Stored bytes allow retry without re-picking
- User can retry failed uploads
- Same persistence/cache flow as initial upload

## Implementation in Real Estate: Property Images

### Current Implementation (property_form.dart)
```dart
class _PropertyFormState extends State<PropertyForm> {
    List<File> _selectedImages = [];
    List<double> _uploadProgress = [];
    List<String?> _uploadedImageUrls = [];
    List<bool> _uploadError = [];
    
    static const int maxImages = 8;
    static const int maxImageSizeBytes = 2 * 1024 * 1024; // 2MB
```

### Image Selection with Compression
```dart
Future<void> _selectImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    // Compress each image
    for (final f in picked) {
        final comp = await _compressIfNeeded(f);
        final bytes = await comp.length();
        if (bytes > maxImageSizeBytes) {
            // Reject too-large images
        }
    }
}

Future<File> _compressIfNeeded(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 75,
        minWidth: 800,
    );
}
```

### Upload with Progress Tracking
```dart
Future<void> _uploadImageAtIndex(int index) async {
    final file = _selectedImages[fileIndex];
    
    final urls = await widget.provider.uploadPropertyImages(
        [file],
        onProgress: (i, sent, total) {
            setState(() => _uploadProgress[index] = total > 0 ? (sent / total) : 0);
        }
    );
}
```

**Enhancements Needed:**
1. Add cache-busting to uploaded URLs
2. Add pending bytes storage for retry
3. Add cache eviction after upload
4. Add explicit persistence after image upload

## Property Documents Implementation

### Current Implementation (property_documents_screen.dart)
```dart
// Uses FilePicker for multiple document types
final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.custom,
    allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'jpg', 'jpeg', 'png'
    ],
);

// Upload using EmailService
String? url;
if (bytes != null) {
    url = await EmailService().uploadBytes(bytes, filename);
} else if (path != null) {
    url = await EmailService().uploadFile(File(path));
}

// Save to provider
final doc = DocumentItem(
    id: '',
    name: filename,
    propertyId: '',
    url: url,
    createdAt: DateTime.now()
);
await prov.saveDocument(doc);
```

**Enhancements Needed:**
1. Add cache-busting to document URLs
2. Add pending bytes/file storage for retry
3. Add progress indication for large files
4. Add document preview capability
5. Add proper error handling and retry

## Web Endpoint Security & File Upload

### Backend File Storage Pattern
```
EmailService.uploadBytes() or uploadFile()
  ↓
Backend API: /api/upload
  ↓
File Validation:
  - Check MIME type
  - Validate file signature (magic bytes)
  - Enforce size limits
  ↓
Store in cloud storage (Firebase Storage/CloudFlare R2)
  ↓
Return signed/public URL with metadata
  ↓
Store metadata in Firestore
```

### URL Format
```
Original: https://storage.example.com/businesses/photo_abc123.jpg
Cached:   https://storage.example.com/businesses/photo_abc123.jpg?t=1735238400000

Document: https://storage.example.com/documents/contract_xyz789.pdf
          (no cache-bust needed for documents unless versioning required)
```

### File Upload Best Practices
1. **Size Limits:**
   - Images: 2-5 MB max
   - Documents: 10-50 MB max
   - Total upload timeout: 30-60 seconds

2. **File Type Validation:**
   - Mobile: Use ImagePicker/FilePicker native validation
   - Web: Browser file picker enforces extensions
   - Backend: Always validate MIME type and file signature

3. **Security Headers:**
   - CORS: Allow only your domains
   - Content-Security-Policy: Prevent embedded scripts
   - X-Content-Type-Options: nosniff (prevent MIME sniffing)

4. **Storage Strategy:**
   - Use cloud storage (Firebase, S3, Cloudflare R2)
   - Enable versioning for documents
   - Set appropriate access controls (private by default)
   - Use signed URLs for temporary access

## Testing Checklist

- [ ] **Image Upload (Mobile):**
  - [ ] Gallery selection works
  - [ ] Camera capture works
  - [ ] Compression reduces file size
  - [ ] Progress indicator updates
  - [ ] Cache-busted URL shows fresh image
  - [ ] Business/provider updates with new photo
  - [ ] Cache cleared properly

- [ ] **Image Upload (Web):**
  - [ ] File picker works
  - [ ] ImagePicker.pickImage() returns bytes (not File)
  - [ ] uploadBytes() handles web bytes correctly
  - [ ] Cache-busting works on web
  - [ ] Image preview updates in real-time

- [ ] **Document Upload (Mobile & Web):**
  - [ ] File picker opens
  - [ ] All file types (PDF, Word, Excel, Image) accepted
  - [ ] File size validation works
  - [ ] Upload shows progress
  - [ ] Document URL accessible
  - [ ] Retry works if upload fails

- [ ] **Cache Behavior:**
  - [ ] Old cached image doesn't appear after upload
  - [ ] CachedNetworkImage refreshes with new URL
  - [ ] Browser dev tools show ?t=timestamp in request
  - [ ] Network request is not cached by browser

- [ ] **Error Handling:**
  - [ ] Network failure shows retry button
  - [ ] Stored bytes allow retry without re-picking
  - [ ] User-friendly error messages
  - [ ] No app crashes on upload failure

## Code Examples

### Complete Business Photo Upload Flow
```dart
Future<void> _pickAndUploadBusinessPhoto() async {
    try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
            source: ImageSource.gallery, 
            imageQuality: 85
        );
        if (xfile == null) return;
        
        final bytes = await xfile.readAsBytes();
        final filename = xfile.name;
        
        // 1. Optimistic UI update
        setState(() {
            _isUploadingPhoto = true;
            _pendingPhotoBytes = bytes;
            _pendingPhotoFilename = filename;
        });
        
        // 2. Upload to backend
        final url = await EmailService().uploadBytes(bytes, filename);
        setState(() => _isUploadingPhoto = false);
        
        if (url != null) {
            // 3. Cache-bust and update UI
            final cachebusted = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
            setState(() => _photoUrl = cachebusted);
            _pendingPhotoBytes = null;
            _pendingPhotoFilename = null;
            
            // 4. Persist to Firestore
            try {
                final businessProvider = context.read<BusinessProvider>();
                final business = businessProvider.currentBusiness;
                if (business != null) {
                    final updated = business.copyWith(photoUrl: cachebusted);
                    await businessProvider.updateBusiness(updated);
                }
            } catch (e) {
                debugPrint('Persist error: $e');
            }
            
            // 5. Clear caches
            await _evictAndRemoveCache(url);
            await _evictAndRemoveCache(cachebusted);
            
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo uploaded'))
            );
        } else {
            _showRetrySnackBar();
        }
    } catch (e) {
        setState(() => _isUploadingPhoto = false);
        _showRetrySnackBar();
    }
}
```

### Complete Document Upload with Web Support
```dart
Future<void> _uploadDocument() async {
    try {
        final result = await FilePicker.platform.pickFiles();
        if (result == null) return;
        
        final file = result.files.first;
        String? url;
        
        // 1. Store pending for retry
        if (file.bytes != null) {
            _pendingBytes = file.bytes;
        } else if (file.path != null) {
            _pendingFile = File(file.path!);
        }
        _pendingFilename = file.name;
        
        // 2. Show loading
        setState(() => _isUploading = true);
        
        // 3. Upload (handles both web bytes and mobile files)
        if (file.bytes != null) {
            url = await EmailService().uploadBytes(file.bytes!, file.name);
        } else {
            url = await EmailService().uploadFile(File(file.path!));
        }
        setState(() => _isUploading = false);
        
        if (url != null) {
            // 4. Cache-bust for documents (optional)
            final cachebusted = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
            
            // 5. Save metadata
            final doc = DocumentItem(
                id: '',
                name: file.name,
                propertyId: _currentPropertyId,
                url: cachebusted,
                createdAt: DateTime.now(),
            );
            await _provider.saveDocument(doc);
            
            // 6. Clear pending
            _pendingBytes = null;
            _pendingFile = null;
            _pendingFilename = null;
            
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document uploaded'))
            );
        }
    } catch (e) {
        setState(() => _isUploading = false);
        _showRetrySnackBar();
    }
}
```

## Related Files
- `lib/presentation/settings/screens/business_settings_screen.dart` - Business photo reference
- `lib/presentation/settings/screens/profile_screen.dart` - User profile photo reference
- `lib/presentation/industry_specific/realestate/widgets/property_form.dart` - Property images (to be enhanced)
- `lib/presentation/industry_specific/realestate/screens/property_documents_screen.dart` - Documents (to be enhanced)
- `lib/services/email_service.dart` - File upload implementation
- `lib/providers/business_provider.dart` - Business data persistence

## Summary

The unified pattern across all photo/document uploads:
1. **Pick & Prepare** - Select file, compress if needed
2. **Optimistic UI** - Update UI immediately, show loading
3. **Upload** - Use EmailService (handles web + mobile)
4. **Cache-Bust** - Add timestamp for fresh fetch
5. **Persist** - Save to Firestore (non-blocking)
6. **Cache-Evict** - Clear old cached image
7. **Retry** - Store pending data for failed uploads

This ensures: **consistency, web compatibility, security, and good UX** across all file upload features.
