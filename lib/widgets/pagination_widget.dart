import 'package:flutter/material.dart';

/// Pagination widget
class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onPreviousPressed;
  final VoidCallback onNextPressed;
  final ValueChanged<int>? onPageSelected;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPreviousPressed,
    required this.onNextPressed,
    this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? onPreviousPressed : null,
          ),
          Text('$currentPage / $totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages ? onNextPressed : null,
          ),
        ],
      ),
    );
  }
}

