import 'package:flutter/material.dart';

class TableMap extends StatelessWidget {
  final List<Map<String, dynamic>> tables;
  final Function(String) onTableSelected;

  const TableMap(
      {super.key, required this.tables, required this.onTableSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        return GestureDetector(
          onTap: () => onTableSelected(table['id']),
          child: Card(
            child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text('Table ${table['number']}'),
                  Text(table['status'] ?? '')
                ])),
          ),
        );
      },
    );
  }
}

