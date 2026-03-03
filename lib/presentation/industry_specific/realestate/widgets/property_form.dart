import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
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

  String _selectedType = 'residential';
  // Stores either local File (mobile/desktop) or XFile (web)
  List<dynamic> _selectedImages = [];
  // On web store in-memory bytes for quick preview
  List<Uint8List?> _selectedImageBytes = [];
  List<double> _uploadProgress = [];
  List<String?> _uploadedImageUrls = [];
  List<bool> _uploadError = [];
  // For retry: store pending bytes and filenames
  List<List<int>?> _pendingImageBytes = [];
  List<String?> _pendingImageFilenames = [];
  bool _isSubmitting = false;

  static const int maxImages = 8;
  static const int maxImageSizeBytes = 2 * 1024 * 1024; // 2MB

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

    _selectedType = widget.initial?.propertyType ?? 'residential';
    _uploadedImageUrls = List<String?>.from(widget.initial?.imageUrls ?? []);
    _selectedImages = [];
    // Use growable lists so we can add/remove items when users pick new images
    _uploadProgress = List<double>.filled(_uploadedImageUrls.length, 1.0, growable: true);
    _uploadError = List<bool>.filled(_uploadedImageUrls.length, false, growable: true);
    _pendingImageBytes = List<List<int>?>.filled(_uploadedImageUrls.length, null, growable: true);
    _pendingImageFilenames = List<String?>.filled(_uploadedImageUrls.length, null, growable: true);
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

  Future<void> _selectImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    // Enforce max images
    if (_uploadedImageUrls.length + _selectedImages.length + images.length >
        maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum of 8 images allowed per property')));
      return;
    }

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
        amenities: widget.initial?.amenities ?? [],
        imageUrls: _uploadedImageUrls.where((u) => u != null).map((u) => u!).toList(),
        status: widget.initial?.status ?? 'available',
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        agentId: widget.initial?.agentId,
        agentName: widget.initial?.agentName,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _titleCtrl,
            decoration: InputDecoration(labelText: 'Property Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionCtrl,
            decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationCtrl,
            decoration: InputDecoration(labelText: 'Location', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required' : null,
          ),
          const SizedBox(height: 12),
          const Text('Property Type'),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedType,
            isExpanded: true,
            items: ['residential', 'commercial', 'land'].map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase()))).toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Price (₦)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) {
              final val = _parsePrice(v ?? '');
              if (val <= 0) return 'Price must be greater than zero';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: _areaCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Area (m²)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _bedroomsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Bedrooms', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _bathroomsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Bathrooms', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _parkingCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Parking Spaces', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 16),
          const Text('Property Images'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectImages,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                const Icon(Icons.image_outlined, size: 48, color: AppColors.primary),
                const SizedBox(height: 8),
                const Text('Tap to select images'),
                const SizedBox(height: 8),
                if (_uploadedImageUrls.where((u) => u != null).isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_uploadedImageUrls.where((u) => u != null).length} image(s) available', style: AppTextStyles.body2.copyWith(color: AppColors.primary))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _uploadedImageUrls.asMap().entries.map((entry) {
                    final i = entry.key;
                    final url = entry.value;
                    // Calculate how many uploaded (existing) images there are so we can map
                    // the _selectedImages array correctly to indices in _uploadedImageUrls.
                    final existingCount = _uploadedImageUrls.length - _selectedImages.length;

                    Widget imageWidget;

                    if (url != null) {
                      imageWidget = Image.network(url, width: 80, height: 80, fit: BoxFit.cover);
                    } else {
                      final selIndex = i - existingCount;
                      if (selIndex >= 0 && selIndex < _selectedImages.length) {
                        if (_selectedImageBytes.length > selIndex && _selectedImageBytes[selIndex] != null) {
                          imageWidget = Image.memory(_selectedImageBytes[selIndex]!, width: 80, height: 80, fit: BoxFit.cover);
                        } else {
                          final sel = _selectedImages[selIndex];
                          if (sel is File) {
                            imageWidget = Image.file(sel, width: 80, height: 80, fit: BoxFit.cover);
                          } else if (sel is XFile) {
                            imageWidget = Image.memory(_selectedImageBytes[selIndex] ?? Uint8List(0), width: 80, height: 80, fit: BoxFit.cover);
                          } else {
                            imageWidget = const SizedBox(width: 80, height: 80);
                          }
                        }
                      } else {
                        imageWidget = const SizedBox(width: 80, height: 80);
                      }
                    }

                    return Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: imageWidget),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              final existingCountInner = _uploadedImageUrls.length - _selectedImages.length;

                              if (i < existingCountInner) {
                                // Removing an already-uploaded image
                                _uploadedImageUrls.removeAt(i);
                                _uploadProgress.removeAt(i);
                                _uploadError.removeAt(i);
                                _pendingImageBytes.removeAt(i);
                                _pendingImageFilenames.removeAt(i);
                              } else {
                                // Removing a newly-selected image that hasn't been uploaded yet
                                final selIndex = i - existingCountInner;
                                if (selIndex >= 0 && selIndex < _selectedImages.length) {
                                  _selectedImages.removeAt(selIndex);
                                  if (_selectedImageBytes.length > selIndex) _selectedImageBytes.removeAt(selIndex);
                                  // Remove the parallel slot in the uploaded arrays
                                  _uploadedImageUrls.removeAt(i);
                                  _uploadProgress.removeAt(i);
                                  _uploadError.removeAt(i);
                                  _pendingImageBytes.removeAt(i);
                                  _pendingImageFilenames.removeAt(i);
                                } else {
                                  // Fallback: remove the slot at i
                                  _uploadedImageUrls.removeAt(i);
                                  _uploadProgress.removeAt(i);
                                  _uploadError.removeAt(i);
                                  _pendingImageBytes.removeAt(i);
                                  _pendingImageFilenames.removeAt(i);
                                }
                              }
                            });
                          },
                          child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                        ),
                      ),
                      if (i < _uploadProgress.length && _uploadProgress[i] > 0 && _uploadProgress[i] < 1)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black.withOpacity(0.35)),
                            child: LinearProgressIndicator(value: _uploadProgress[i], minHeight: 6, backgroundColor: Colors.white.withOpacity(0.2), valueColor: const AlwaysStoppedAnimation(AppColors.primary)),
                          ),
                        ),
                      if (i < _uploadError.length && _uploadError[i])
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: GestureDetector(onTap: () => _retryUploadImage(i), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)))),
                        )
                    ]);
                  }).toList(),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: _isSubmitting ? null : _handleSubmit, child: _isSubmitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white), strokeWidth: 2)) : Text(widget.submitText)))
          ])
        ],
      ),
    );
  }
}
