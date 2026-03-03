import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';

class PdfPreviewPage extends StatelessWidget {
  final List<int> pdfBytes;
  const PdfPreviewPage({super.key, required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Preview')),
      body: PdfPreview(
        build: (_) async => Uint8List.fromList(pdfBytes),
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
