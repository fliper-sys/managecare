import 'package:flutter/material.dart';

import '../../../core/utils/worker_permissions.dart';

class PermissionSelector extends StatefulWidget {
  final List<String> availablePermissions;
  final Set<String> selectedPermissions;
  final ValueChanged<Set<String>>? onChanged;

  const PermissionSelector({
    super.key,
    this.availablePermissions = const [],
    this.selectedPermissions = const {},
    this.onChanged,
  });

  @override
  State<PermissionSelector> createState() => _PermissionSelectorState();
}

class _PermissionSelectorState extends State<PermissionSelector> {
  late final Map<String, bool> permissions;

  @override
  void initState() {
    super.initState();
    final availablePermissions = widget.availablePermissions.isEmpty
        ? WorkerPermissions.getAllPermissions()
        : widget.availablePermissions;
    permissions = {
      for (final permission in availablePermissions)
        permission: widget.selectedPermissions.contains(permission),
    };
  }

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
            title: Text(WorkerPermissions.getPermissionLabel(entry.key)),
            value: entry.value,
            onChanged: (value) {
              setState(() => permissions[entry.key] = value ?? false);
              widget.onChanged?.call(
                permissions.entries
                    .where((permission) => permission.value)
                    .map((permission) => permission.key)
                    .toSet(),
              );
            },
          ),
        ),
      ],
    );
  }
}
