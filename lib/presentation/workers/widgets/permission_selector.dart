import 'package:flutter/material.dart';

class PermissionSelector extends StatefulWidget {
  const PermissionSelector({super.key});

  @override
  State<PermissionSelector> createState() => _PermissionSelectorState();
}

class _PermissionSelectorState extends State<PermissionSelector> {
  final permissions = {
    'Sales Management': false,
    'Inventory Management': false,
    'Customer Management': false,
    'Reports Access': false,
    'Worker Management': false,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permissions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...permissions.entries.map(
          (entry) => CheckboxListTile(
            title: Text(entry.key),
            value: entry.value,
            onChanged: (value) {
              setState(() => permissions[entry.key] = value ?? false);
            },
          ),
        ),
      ],
    );
  }
}

