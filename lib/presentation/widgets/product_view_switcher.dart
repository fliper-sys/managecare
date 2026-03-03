import 'package:flutter/material.dart';

/// Toggle button for switching between list and grid view
class ProductViewSwitcher extends StatelessWidget {
  final bool isGridView;
  final VoidCallback onToggle;

  const ProductViewSwitcher({
    required this.isGridView,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isGridView ? 'Switch to list view' : 'Switch to grid view',
      child: IconButton(
        icon: Icon(isGridView ? Icons.list : Icons.grid_3x3),
        onPressed: onToggle,
        tooltip: isGridView ? 'List View' : 'Grid View',
      ),
    );
  }
}
