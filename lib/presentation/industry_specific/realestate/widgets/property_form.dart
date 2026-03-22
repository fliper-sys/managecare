import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/real_estate_provider.dart';

typedef OnPropertySubmit = Future<void> Function(Property property);

class PropertyForm extends StatefulWidget {
  final Property? initial;
  final OnPropertySubmit onSubmit;
  final RealEstateProvider provider;
  final String submitText;

  const PropertyForm({
    Key? key,
    this.initial,
    required this.onSubmit,
    required this.provider,
    this.submitText = 'Save',
  }) : super(key: key);

  @override
  State<PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<PropertyForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _bedroomsCtrl;
  late TextEditingController _bathroomsCtrl;
  late TextEditingController _parkingCtrl;
  late TextEditingController _yearBuiltCtrl;
  late TextEditingController _floorsCtrl;
  late TextEditingController _unitsCtrl;
  late TextEditingController _agentNameCtrl;

  String _selectedType = 'residential';
  String _selectedStatus = 'available';
  String? _selectedTenantId;
  String? _selectedAgentId;

  // Image handling
  List<dynamic> _selectedImages = [];
  List<Uint8List?> _selectedImageBytes = [];
  List<double> _uploadProgress = [];
  List<String?> _uploadedImageUrls = [];
  List<bool> _uploadError = [];
  List<List<int>?> _pendingImageBytes = [];
  List<String?> _pendingImageFilenames = [];

  // Document handling
  List<PlatformFile> _selectedDocuments = [];
  List<String?> _uploadedDocumentUrls = [];
  List<double> _documentUploadProgress = [];
  List<bool> _documentUploadError = [];

  // Amenities
  final List<String> _availableAmenities = [
    'Swimming Pool', 'Gym', 'Parking', 'Security', 'Garden', 'Balcony',
    'Air Conditioning', 'Heating', 'Internet', 'Cable TV', 'Laundry',
    'Storage', 'Elevator', 'Fireplace', 'Dishwasher', 'Walk-in Closet'
  ];
  List<String> _selectedAmenities = [];

  bool _isSubmitting = false;

  static const int maxImages = 8;
  static const int maxDocuments = 5;
  static const int maxImageSizeBytes = 2 * 1024 * 1024; // 2MB
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024; // 10MB

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial?.title ?? '');
    _descriptionCtrl =
        TextEditingController(text: widget.initial?.description ?? '');
    _locationCtrl = TextEditingController(text: widget.initial?.location ?? '');
    _priceCtrl = TextEditingController(
        text: widget.initial != null ? widget.initial!.price.toString() : '');
    _areaCtrl = TextEditingController(
        text: widget.initial != null ? widget.initial!.area.toString() : '');
    _bedroomsCtrl = TextEditingController(
        text: widget.initial != null ? widget.initial!.bedrooms.toString() : '1');
    _bathroomsCtrl = TextEditingController(
        text: widget.initial != null ? widget.initial!.bathrooms.toString() : '1');
    _parkingCtrl = TextEditingController(
        text: widget.initial != null ? widget.initial!.parking.toString() : '0');
    _yearBuiltCtrl = TextEditingController(text: widget.initial != null ? '2024' : '');
    _floorsCtrl = TextEditingController(text: widget.initial != null ? '1' : '1');
    _unitsCtrl = TextEditingController(text: widget.initial != null ? '1' : '1');
    _agentNameCtrl = TextEditingController(text: widget.initial?.agentName ?? '');

    _selectedType = widget.initial?.propertyType ?? 'residential';
    _selectedStatus = widget.initial?.status ?? 'available';
    _selectedTenantId = null; // Will be set if editing existing property with tenant
    _selectedAgentId = widget.initial?.agentId;
    _selectedAmenities = List<String>.from(widget.initial?.amenities ?? []);

    _uploadedImageUrls = List<String?>.from(widget.initial?.imageUrls ?? []);
    _selectedImages = [];
    _uploadProgress = List<double>.filled(_uploadedImageUrls.length, 1.0, growable: true);
    _uploadError = List<bool>.filled(_uploadedImageUrls.length, false, growable: true);
    _pendingImageBytes = List<List<int>?>.filled(_uploadedImageUrls.length, null, growable: true);
    _pendingImageFilenames = List<String?>.filled(_uploadedImageUrls.length, null, growable: true);

    // Initialize document lists
    _uploadedDocumentUrls = [];
    _documentUploadProgress = [];
    _documentUploadError = [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _parkingCtrl.dispose();
    _yearBuiltCtrl.dispose();
    _floorsCtrl.dispose();
    _unitsCtrl.dispose();
    _agentNameCtrl.dispose();
    super.dispose();
  }

  Future<File> _compressIfNeeded(File file) async {
    try {
      // Only attempt compression on non-web platforms
      if (kIsWeb) return file;
      final targetPath = '${file.path}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 75,
        minWidth: 800,
      );
      if (result == null) return file;
      return File(result.path);
    } catch (_) {
      return file;
    }
  }

  Future<void> _selectDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      if (_uploadedDocumentUrls.length + result.files.length > maxDocuments) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Maximum of 5 documents allowed per property')));
        return;
      }

      setState(() {
        _selectedDocuments.addAll(result.files);
        _documentUploadProgress.addAll(List<double>.filled(result.files.length, 0.0));
        _documentUploadError.addAll(List<bool>.filled(result.files.length, false));
        _uploadedDocumentUrls.addAll(List<String?>.filled(result.files.length, null));
      });

      // Start uploading documents
      for (int i = 0; i < result.files.length; i++) {
        final idx = _uploadedDocumentUrls.length - result.files.length + i;
        await _uploadDocumentAtIndex(idx);
      }
    }
  }

  Future<void> _uploadDocumentAtIndex(int index) async {
    if (index < 0 || index >= _selectedDocuments.length) return;

    final document = _selectedDocuments[index - (_uploadedDocumentUrls.length - _selectedDocuments.length)];
    if (document.bytes == null && document.path == null) return;

    try {
      setState(() {
        _documentUploadError[index] = false;
        _documentUploadProgress[index] = 0.0;
      });

      List<int> bytes;
      String filename;

      if (document.bytes != null) {
        bytes = document.bytes!;
        filename = document.name;
      } else {
        final file = File(document.path!);
        bytes = await file.readAsBytes();
        filename = document.name;
      }

      if (bytes.length > maxDocumentSizeBytes) {
        setState(() => _documentUploadError[index] = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Document ${document.name} is too large (max 10MB)')));
        }
        return;
      }

      // Create a temporary file for upload
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes);

      final urls = await widget.provider.uploadPropertyDocuments([tempFile],
          onProgress: (i, sent, total) {
        if (mounted) {
          setState(() => _documentUploadProgress[index] = total > 0 ? (sent / total) : 0);
        }
      });

      if (urls.isNotEmpty) {
        setState(() {
          _uploadedDocumentUrls[index] = urls.first;
          _documentUploadProgress[index] = 1.0;
          _documentUploadError[index] = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Document ${document.name} uploaded successfully')));
        }
      } else {
        setState(() => _documentUploadError[index] = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload document')));
        }
      }

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}
    } catch (e) {
      setState(() => _documentUploadError[index] = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Document upload failed: $e')));
      }
    }
  }

  Future<void> _selectImages() async {
    if (_uploadedImageUrls.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum of 8 images allowed per property')));
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      final remainingSlots = maxImages - _uploadedImageUrls.length;
      if (images.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You can only add $remainingSlots more images')));
        await _handleImageSelection(images.sublist(0, remainingSlots));
      } else {
        await _handleImageSelection(images);
      }
    }
  }

  Future<void> _handleImageSelection(List<XFile> images) async {
    final List<dynamic> newSelected = [];
    final List<Uint8List?> newBytes = [];

    // Compress and check sizes (platform-specific)
    for (final x in images) {
      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        if (bytes.length > maxImageSizeBytes) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'An image is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB). Please choose smaller images.')));
          return;
        }
        newSelected.add(x);
        newBytes.add(bytes);
      } else {
        final f = File(x.path);
        final comp = await _compressIfNeeded(f);
        final bytes = await comp.length();
        if (bytes > maxImageSizeBytes) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'An image is too large after compression (${(bytes / 1024 / 1024).toStringAsFixed(2)} MB). Please choose smaller images.')));
          return;
        }
        newSelected.add(comp);
        newBytes.add(null);
      }
    }

    setState(() {
      // Use safe add operations to handle immutable/fixed-length lists gracefully
      try {
        _selectedImages.addAll(newSelected);
      } catch (e) {
        debugPrint('addAll failed on _selectedImages: $e');
        _selectedImages = List<dynamic>.from(_selectedImages)..addAll(newSelected);
      }

      try {
        _selectedImageBytes.addAll(newBytes);
      } catch (e) {
        debugPrint('addAll failed on _selectedImageBytes: $e');
        _selectedImageBytes = List<Uint8List?>.from(_selectedImageBytes)..addAll(newBytes);
      }

      try {
        _uploadProgress.addAll(List<double>.filled(newSelected.length, 0.0));
      } catch (e) {
        debugPrint('addAll failed on _uploadProgress: $e');
        _uploadProgress = List<double>.from(_uploadProgress)..addAll(List<double>.filled(newSelected.length, 0.0));
      }

      try {
        _uploadedImageUrls.addAll(List<String?>.filled(newSelected.length, null));
      } catch (e) {
        debugPrint('addAll failed on _uploadedImageUrls: $e');
        _uploadedImageUrls = List<String?>.from(_uploadedImageUrls)..addAll(List<String?>.filled(newSelected.length, null));
      }

      try {
        _uploadError.addAll(List<bool>.filled(newSelected.length, false));
      } catch (e) {
        debugPrint('addAll failed on _uploadError: $e');
        _uploadError = List<bool>.from(_uploadError)..addAll(List<bool>.filled(newSelected.length, false));
      }

      try {
        _pendingImageBytes.addAll(List<List<int>?>.filled(newSelected.length, null));
      } catch (e) {
        debugPrint('addAll failed on _pendingImageBytes: $e');
        _pendingImageBytes = List<List<int>?>.from(_pendingImageBytes)..addAll(List<List<int>?>.filled(newSelected.length, null));
      }

      try {
        _pendingImageFilenames.addAll(List<String?>.filled(newSelected.length, null));
      } catch (e) {
        debugPrint('addAll failed on _pendingImageFilenames: $e');
        _pendingImageFilenames = List<String?>.from(_pendingImageFilenames)..addAll(List<String?>.filled(newSelected.length, null));
      }
    });

    // Start uploading new images
    for (int i = 0; i < newSelected.length; i++) {
      final idx = _uploadedImageUrls.indexWhere((u) => u == null);
      if (idx >= 0) await _uploadImageAtIndex(idx);
    }
  }

  Future<void> _uploadImageAtIndex(int index) async {
    if (index < 0 || index >= _uploadedImageUrls.length) return;
    try {
      setState(() {
        _uploadError[index] = false;
        _uploadProgress[index] = 0.0;
      });

      // Compute file index relative to selected images
      final int existingCount = _uploadedImageUrls.length - _selectedImages.length;
      final int fileIndex = index - existingCount;
      if (fileIndex < 0 || fileIndex >= _selectedImages.length) return;

      final item = _selectedImages[fileIndex];

      // Handle web (XFile) and native File differently
      List<int>? bytes;
      String? filename;

      if (kIsWeb && item is XFile) {
        bytes = await item.readAsBytes();
        filename = item.name;
      } else if (item is File) {
        bytes = await item.readAsBytes();
        filename = item.path.split(Platform.pathSeparator).last;
      }

      _pendingImageBytes[index] = bytes;
      _pendingImageFilenames[index] = filename;

      final urls = await widget.provider.uploadPropertyImages([item],
          onProgress: (i, sent, total) {
        if (mounted)
          setState(() => _uploadProgress[index] = total > 0 ? (sent / total) : 0);
      });

      if (urls.isNotEmpty) {
        final url = urls.first;
        // Add cache-busting to prevent stale image display
        final cacheBustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
        
        setState(() {
          _uploadedImageUrls[index] = cacheBustedUrl;
          _uploadProgress[index] = 1.0;
          _uploadError[index] = false;
        });

        // Clear cache for fresh image display (also clear base URL)
        await _evictAndRemoveCache(url);
        await _evictAndRemoveCache(cacheBustedUrl);
      } else {
        setState(() => _uploadError[index] = true);        if (mounted) {
          final msg = widget.provider.errorMessage.isNotEmpty ? widget.provider.errorMessage : 'Failed to upload image';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            action: SnackBarAction(label: 'Retry', onPressed: () => _retryUploadImage(index)),
          ));
        }      }
    } catch (e) {
      setState(() => _uploadError[index] = true);
    }
  }

  Future<void> _evictAndRemoveCache(String url) async {
    if (url.isEmpty) return;
    final baseUrl = url.split('?').first;

    try {
      await CachedNetworkImageProvider(url).evict();
    } catch (e) {
      debugPrint('Evict image (url) error: $e');
    }

    if (baseUrl != url) {
      try {
        await CachedNetworkImageProvider(baseUrl).evict();
      } catch (e) {
        debugPrint('Evict image (baseUrl) error: $e');
      }
    }

    try {
      await DefaultCacheManager().removeFile(url);
    } catch (e) {
      debugPrint('Remove file from cache error: $e');
    }

    if (baseUrl != url) {
      try {
        await DefaultCacheManager().removeFile(baseUrl);
      } catch (_) {}
    }
  }

  Future<void> _retryUploadImage(int index) async {
    if (index < 0 || index >= _uploadedImageUrls.length) return;
if (_pendingImageBytes[index] == null || _pendingImageBytes[index]!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cached image data for retry')));
      return;
    }

    try {
      setState(() {
        _uploadError[index] = false;
        _uploadProgress[index] = 0.0;
      });

      final bytes = _pendingImageBytes[index]!;
      final filename = _pendingImageFilenames[index] ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Create temp file from bytes for upload
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      try {
        await tempFile.writeAsBytes(bytes);
      } catch (e) {
        if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { try { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Temp file write failed: $e'))); } catch (e) { debugPrint('ShowSnackBar failed: $e'); } });
        setState(() => _uploadError[index] = true);
        return;
      }

      final urls = await widget.provider.uploadPropertyImages([tempFile],
          onProgress: (i, sent, total) {
        if (mounted)
          setState(() => _uploadProgress[index] = total > 0 ? (sent / total) : 0);
      });

      if (urls.isNotEmpty) {
        final url = urls.first;
        // Add cache-busting
        final cacheBustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

        setState(() {
          _uploadedImageUrls[index] = cacheBustedUrl;
          _uploadProgress[index] = 1.0;
          _uploadError[index] = false;
        });

        // Clear caches
        await _evictAndRemoveCache(url);
        await _evictAndRemoveCache(cacheBustedUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image uploaded successfully')));
        }
      } else {
        setState(() => _uploadError[index] = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image')));
        }
      }

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}
    } catch (e) {
      setState(() => _uploadError[index] = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Retry failed: $e')));
      }
    }
  }

  String _sanitizePrice(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9\.]'), '');
  }

  double _parsePrice(String raw) {
    final s = _sanitizePrice(raw);
    return double.tryParse(s) ?? 0.0;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedImageUrls.isEmpty || _uploadedImageUrls.where((u) => u!=null).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please upload at least one image for the property')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final property = Property(
        id: widget.initial?.id ?? '',
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        propertyType: _selectedType,
        price: _parsePrice(_priceCtrl.text),
        area: double.tryParse(_areaCtrl.text) ?? 0,
        bedrooms: int.tryParse(_bedroomsCtrl.text) ?? 0,
        bathrooms: int.tryParse(_bathroomsCtrl.text) ?? 0,
        parking: int.tryParse(_parkingCtrl.text) ?? 0,
        amenities: _selectedAmenities,
        imageUrls: _uploadedImageUrls.where((u) => u != null).map((u) => u!).toList(),
        status: _selectedStatus,
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        agentId: _selectedAgentId,
        agentName: _agentNameCtrl.text.trim().isNotEmpty ? _agentNameCtrl.text.trim() : null,
      );

      await widget.onSubmit(property);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.submitText} successful')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            _buildSectionHeader('Basic Information'),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Property Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'e.g., Modern 3BR Apartment in Lekki'
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Detailed description of the property...'
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Full address or location description'
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required' : null,
            ),
            const SizedBox(height: 16),

            // Property Type and Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Property Type'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['residential', 'commercial', 'land'].map((type) =>
                          DropdownMenuItem(value: type, child: Text(type.toUpperCase()))
                        ).toList(),
                        onChanged: (v) => setState(() => _selectedType = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['available', 'rented', 'sold', 'maintenance'].map((status) =>
                          DropdownMenuItem(value: status, child: Text(status.toUpperCase()))
                        ).toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pricing Section
            _buildSectionHeader('Pricing & Financial'),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Price (₦)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Monthly rent or sale price'
              ),
              validator: (v) {
                final val = _parsePrice(v ?? '');
                if (val <= 0) return 'Price must be greater than zero';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Property Details Section
            _buildSectionHeader('Property Details'),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _areaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Area (m²)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                )
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: _bedroomsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Bedrooms',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                )
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: _bathroomsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Bathrooms',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                )
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _parkingCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Parking Spaces',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                )
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: _yearBuiltCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Year Built',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                )
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: _floorsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Floors',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                )
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Units',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
              )
            ),
            const SizedBox(height: 16),

            // Agent Information Section
            _buildSectionHeader('Agent Information'),
            TextFormField(
              controller: _agentNameCtrl,
              decoration: InputDecoration(
                labelText: 'Agent Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Name of the listing agent'
              ),
            ),
            const SizedBox(height: 16),

            // Amenities Section
            _buildSectionHeader('Amenities'),
            _buildAmenitiesSelector(),
            const SizedBox(height: 16),

            // Images Section
            _buildSectionHeader('Property Images'),
            _buildImageUploadSection(),
            const SizedBox(height: 16),

            // Documents Section
            _buildSectionHeader('Documents'),
            _buildDocumentUploadSection(),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(widget.submitText, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildAmenitiesSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableAmenities.map((amenity) {
        final isSelected = _selectedAmenities.contains(amenity);
        return FilterChip(
          label: Text(amenity),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedAmenities.add(amenity);
              } else {
                _selectedAmenities.remove(amenity);
              }
            });
          },
          backgroundColor: Colors.grey[100],
          selectedColor: AppColors.primary.withOpacity(0.2),
          checkmarkColor: AppColors.primary,
        );
      }).toList(),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _selectImages,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Tap to add property images', style: TextStyle(color: Colors.grey)),
                  Text('(Max 8 images, 2MB each)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        if (_uploadedImageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _uploadedImageUrls.length,
              itemBuilder: (context, index) {
                final url = _uploadedImageUrls[index];
                if (url == null) return const SizedBox.shrink();

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _selectDocuments,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_file, size: 24, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('Tap to add documents', style: TextStyle(color: Colors.grey)),
                  Text('(PDF, DOC, Images - Max 10MB)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        if (_selectedDocuments.isNotEmpty) ...[
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedDocuments.length,
            itemBuilder: (context, index) {
              final doc = _selectedDocuments[index];
              final progress = index < _documentUploadProgress.length ? _documentUploadProgress[index] : 0.0;
              final hasError = index < _documentUploadError.length ? _documentUploadError[index] : false;
              final isUploaded = index < _uploadedDocumentUrls.length && _uploadedDocumentUrls[index] != null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getDocumentIcon(doc.extension),
                      color: hasError ? Colors.red : isUploaded ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${(doc.size / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          if (progress > 0 && progress < 1) ...[
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: progress),
                          ],
                          if (hasError) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Upload failed',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                          if (isUploaded) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Uploaded successfully',
                              style: TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isUploaded && !hasError)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeDocument(index),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  IconData _getDocumentIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _uploadedImageUrls.removeAt(index);
      if (index < _uploadProgress.length) _uploadProgress.removeAt(index);
      if (index < _uploadError.length) _uploadError.removeAt(index);
      if (index < _pendingImageBytes.length) _pendingImageBytes.removeAt(index);
      if (index < _pendingImageFilenames.length) _pendingImageFilenames.removeAt(index);
    });
  }

  void _removeDocument(int index) {
    setState(() {
      _selectedDocuments.removeAt(index);
      if (index < _documentUploadProgress.length) _documentUploadProgress.removeAt(index);
      if (index < _documentUploadError.length) _documentUploadError.removeAt(index);
      if (index < _uploadedDocumentUrls.length) _uploadedDocumentUrls.removeAt(index);
    });
  }
}
