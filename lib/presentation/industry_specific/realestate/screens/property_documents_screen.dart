import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../core/utils/context_extensions.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/real_estate_provider.dart';
import '../../../../services/email_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDocumentsScreen extends StatefulWidget {
  const PropertyDocumentsScreen({super.key});

  @override
  State<PropertyDocumentsScreen> createState() =>
      _PropertyDocumentsScreenState();
}

class _PropertyDocumentsScreenState extends State<PropertyDocumentsScreen> {
  File? _lastPickedDocument;
  // For web compatibility
  List<int>? _lastPickedBytes;
  String? _lastPickedFilename;
  @override
  Widget build(BuildContext context) {
    final prov = context.tryRead<RealEstateProvider>();
    if (prov == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Documents')),
        body: const Center(child: Text('Service not available. Try again.')),
      );
    }

    final docs = prov.documents;
    return Scaffold(
      appBar: AppBar(title: const Text('Property Documents')),
      body: docs.isEmpty
          ? const Center(child: Text('No documents uploaded'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final d = docs[index];
                final name = d.name.isNotEmpty ? d.name : 'Document';
                final prop = d.propertyId ?? '-';
                final date =
                    d.createdAt.toLocal().toIso8601String().split('T').first;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(name),
                    subtitle: Text('Property: $prop • $date'),
                    trailing: ElevatedButton(
                        onPressed: () async {
                          if (d.url == null || d.url!.isEmpty) return;
                          final uri = Uri.parse(d.url!);
                          try {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Could not open document')));
                          }
                        },
                        child: const Text('Open')),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Pick file using file_picker (supports docs, spreadsheets, pdfs, images)
          try {
            final result = await FilePicker.platform.pickFiles(
              allowMultiple: false,
              type: FileType.custom,
              allowedExtensions: [
                'pdf',
                'doc',
                'docx',
                'xls',
                'xlsx',
                'csv',
                'jpg',
                'jpeg',
                'png'
              ],
            );
            if (result == null || result.files.isEmpty) return;
            final picked = result.files.single;
            final path = picked.path;
            final bytes = picked.bytes;
            final filename = picked.name;
            if ((path == null || path.isEmpty) && (bytes == null || bytes.isEmpty)) return;

            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Uploading...')));

            String? url;
            if (bytes != null && bytes.isNotEmpty) {
              _lastPickedBytes = bytes;
              _lastPickedFilename = filename;
              url = await EmailService().uploadBytes(bytes, filename);
            } else if (path != null) {
              final file = File(path);
              _lastPickedDocument = file;
              _lastPickedFilename = filename;
              url = await EmailService().uploadFile(file);
            }

            if (url != null) {
              // Add cache-busting to prevent stale document display
              final cacheBustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
              final doc = DocumentItem(
                  id: '',
                  name: filename,
                  propertyId: '',
                  url: cacheBustedUrl,
                  createdAt: DateTime.now());
              await prov.saveDocument(doc);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document uploaded')));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Upload failed'),
                  action: SnackBarAction(
                      label: 'Retry', onPressed: _retryUploadDocument)));
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Upload error: $e'),
                action: SnackBarAction(
                    label: 'Retry', onPressed: _retryUploadDocument)));
          }
        },
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Future<void> _retryUploadDocument() async {
    if ((_lastPickedDocument == null) && (_lastPickedBytes == null || _lastPickedFilename == null)) return;
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Retrying upload...')));
      String? url;
      String name;
      if (_lastPickedBytes != null && _lastPickedFilename != null) {
        url = await EmailService().uploadBytes(_lastPickedBytes!, _lastPickedFilename!);
        name = _lastPickedFilename!;
      } else if (_lastPickedDocument != null) {
        url = await EmailService().uploadFile(_lastPickedDocument!);
        name = _lastPickedDocument!.path.split('/').last;
      } else {
        return;
      }

      if (url != null) {
        // Add cache-busting to prevent stale document display
        final cacheBustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
        final doc = DocumentItem(
            id: '',
            name: name,
            propertyId: '',
            url: cacheBustedUrl,
            createdAt: DateTime.now());
        final prov = context.tryRead<RealEstateProvider>();
        if (prov != null) {
          await prov.saveDocument(doc);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Document uploaded')));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Service not available. Retry later.')));
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Retry failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Retry error: $e')));
    }
  }
}

