import 'package:flutter/material.dart';

class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'RECEIPT',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const ListTile(
            title: Text('Item 1'),
            trailing: Text('\$25'),
          ),
          const ListTile(
            title: Text('Item 2'),
            trailing: Text('\$50'),
          ),
          const Divider(),
          const ListTile(
            title: Text('Total'),
            trailing: Text('\$75'),
            dense: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Date: ${DateTime.now()}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

