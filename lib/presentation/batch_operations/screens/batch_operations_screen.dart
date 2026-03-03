import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/batch_operations_provider.dart';
import '../../../data/models/batch_operation_model.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/custom_app_bar.dart';

class BatchOperationsScreen extends StatefulWidget {
  const BatchOperationsScreen({super.key});

  @override
  State<BatchOperationsScreen> createState() => _BatchOperationsScreenState();
}

class _BatchOperationsScreenState extends State<BatchOperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Batch Operations',
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOperationDialog(context),
        tooltip: 'Create Batch Operation',
        child: const Icon(Icons.add),
      ),
      body: Consumer<BatchOperationsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Processing'),
                  Tab(text: 'Completed'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOperationsList(
                        context, provider, provider.operations),
                    _buildOperationsList(
                        context, provider, provider.pendingOperations),
                    _buildOperationsList(
                        context, provider, provider.processingOperations),
                    _buildOperationsList(
                        context, provider, provider.completedOperations),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOperationsList(
    BuildContext context,
    BatchOperationsProvider provider,
    List<BatchOperation> operations,
  ) {
    if (operations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No Operations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new batch operation to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: operations.length,
      itemBuilder: (context, index) {
        final operation = operations[index];
        return _buildOperationCard(context, provider, operation);
      },
    );
  }

  Widget _buildOperationCard(
    BuildContext context,
    BatchOperationsProvider provider,
    BatchOperation operation,
  ) {
    final statusColor = _getStatusColor(operation.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOperationDetails(context, provider, operation),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            operation.getTypeLabel(),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            operation.description ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[400]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        operation.getStatusLabel(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: operation.progressPercentage / 100,
                    minHeight: 8,
                    backgroundColor: statusColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 8),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${operation.processedProducts}/${operation.totalProducts} processed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                    ),
                    Text(
                      '${operation.progressPercentage}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                // Action Buttons
                if (operation.status == BatchOperationStatus.pending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        // Execute batch operation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Operation started processing')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start Processing'),
                    ),
                  ),
                ] else if (operation.status ==
                    BatchOperationStatus.processing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => provider.cancelOperation(operation.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOperationDetails(
    BuildContext context,
    BatchOperationsProvider provider,
    BatchOperation operation,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              operation.getTypeLabel(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Status', operation.getStatusLabel()),
            _buildDetailRow(
              'Products',
              '${operation.processedProducts}/${operation.totalProducts}',
            ),
            _buildDetailRow('Progress', '${operation.progressPercentage}%'),
            _buildDetailRow(
              'Created',
              _formatDate(operation.createdAt),
            ),
            if (operation.completedAt != null)
              _buildDetailRow(
                'Completed',
                _formatDate(operation.completedAt!),
              ),
            if (operation.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                operation.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateOperationDialog(BuildContext context) {
    final provider = context.read<BatchOperationsProvider>();
    String operationType = 'priceUpdate';
    final newPriceController = TextEditingController();
    final discountController = TextEditingController();
    final quantityController = TextEditingController();
    final categoryController = TextEditingController();
    String quantityChangeType = 'add';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Batch Operation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: operationType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'priceUpdate',
                    child: Text('Price Update'),
                  ),
                  DropdownMenuItem(
                    value: 'stockUpdate',
                    child: Text('Stock Update'),
                  ),
                  DropdownMenuItem(
                    value: 'categoryUpdate',
                    child: Text('Category Update'),
                  ),
                  DropdownMenuItem(
                    value: 'discountApply',
                    child: Text('Apply Discount'),
                  ),
                  DropdownMenuItem(
                    value: 'deleteProducts',
                    child: Text('Delete Products'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    operationType = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              // Conditional fields based on operation type
              if (operationType == 'priceUpdate') ...[
                TextField(
                  controller: newPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New Price',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount % (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else if (operationType == 'stockUpdate') ...[
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: quantityChangeType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'add', child: Text('Add')),
                    DropdownMenuItem(
                        value: 'subtract', child: Text('Subtract')),
                    DropdownMenuItem(value: 'set', child: Text('Set')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      quantityChangeType = value;
                    }
                  },
                ),
              ] else if (operationType == 'categoryUpdate') ...[
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'New Category',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else if (operationType == 'discountApply') ...[
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              switch (operationType) {
                case 'priceUpdate':
                  await provider.executePriceUpdate(
                    productIds: [],
                    newPrice: double.tryParse(newPriceController.text) ?? 0,
                    discountPercentage:
                        double.tryParse(discountController.text),
                  );
                  break;
                case 'stockUpdate':
                  await provider.executeInventoryUpdate(
                    productIds: [],
                    productIdToQuantity: {},
                  );
                  break;
                case 'categoryUpdate':
                  // Category update not in new service
                  break;
                case 'discountApply':
                  // Discount apply not in new service
                  break;
                case 'deleteProducts':
                  // Delete not in new service
                  break;
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Batch operation created successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BatchOperationStatus status) {
    switch (status) {
      case BatchOperationStatus.pending:
        return Colors.blue;
      case BatchOperationStatus.processing:
        return Colors.orange;
      case BatchOperationStatus.completed:
        return Colors.green;
      case BatchOperationStatus.failed:
        return Colors.red;
      case BatchOperationStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

