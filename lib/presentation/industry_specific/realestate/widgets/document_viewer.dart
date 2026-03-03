import 'package:flutter/material.dart';

class DocumentViewer extends StatelessWidget {
  final String documentName;
  final String documentUrl;

  const DocumentViewer(
      {super.key, required this.documentName, required this.documentUrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.document_scanner),
        title: Text(documentName),
        trailing: const Icon(Icons.open_in_new),
        onTap: () {
          // TODO: open document
        },
      ),
    );
  }
}

