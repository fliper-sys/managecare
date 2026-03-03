import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/restaurant_provider.dart';
import '../../../../providers/business_provider.dart';

class BarOrdersScreen extends StatefulWidget {
  const BarOrdersScreen({super.key});

  @override
  State<BarOrdersScreen> createState() => _BarOrdersScreenState();
}

class _BarOrdersScreenState extends State<BarOrdersScreen> {
  String _filterStatus = 'pending'; // pending, preparing, ready

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business != null) {
        context.read<RestaurantProvider>().setBusinessId(business.id);
        context.read<RestaurantProvider>().initializeOrders(businessId: business.id);
      } else {
        context.read<RestaurantProvider>().initializeOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bar Orders'),
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade700,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Consumer<RestaurantProvider>(
                builder: (context, provider, _) {
                  final pendingCount = provider.orders
                      .where((o) => o.status == 'pending')
                      .length;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Pending: $pendingCount',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Consumer<RestaurantProvider>(
        builder: (context, provider, _) {
          final filteredOrders =
              provider.orders.where((o) => o.status == _filterStatus).toList();

          return Column(
            children: [
              // Filter Buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _FilterButton(
                      label: 'Pending',
                      isActive: _filterStatus == 'pending',
                      onTap: () => setState(() => _filterStatus = 'pending'),
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _FilterButton(
                      label: 'Preparing',
                      isActive: _filterStatus == 'preparing',
                      onTap: () => setState(() => _filterStatus = 'preparing'),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _FilterButton(
                      label: 'Ready',
                      isActive: _filterStatus == 'ready',
                      onTap: () => setState(() => _filterStatus = 'ready'),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
              // Orders List
              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.local_bar,
                              size: 64,
                              color: AppColors.border,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No $_filterStatus orders',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          return _OrderCard(
                            order: filteredOrders[index],
                            provider: provider,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _FilterButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final RestaurantOrder order;
  final RestaurantProvider provider;

  const _OrderCard({
    required this.order,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = order.status == 'pending'
        ? Colors.red
        : order.status == 'preparing'
            ? Colors.orange
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Table Number, Time & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Table ${order.tableNumber ?? 'N/A'}',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(order.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.menuItemName}',
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.specialInstructions != null)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Note',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              )),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              if (order.status == 'pending')
                Expanded(
                  child: CustomButton(
                    text: 'Start Preparing',
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                    onPressed: () {
                      provider.updateOrderStatus(order.id, 'preparing');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order moved to preparing'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              if (order.status == 'preparing')
                Expanded(
                  child: CustomButton(
                    text: 'Ready for Pickup',
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                    onPressed: () {
                      provider.updateOrderStatus(order.id, 'ready');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order ready for pickup'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              if (order.status == 'ready')
                Expanded(
                  child: CustomButton(
                    text: 'View Details',
                    backgroundColor: AppColors.primary,
                    textColor: Colors.white,
                    onPressed: () => _showOrderDetails(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}',
                          style: AppTextStyles.heading4,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: order.status == 'pending'
                                ? Colors.red
                                : order.status == 'preparing'
                                    ? Colors.orange
                                    : Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Table ${order.tableNumber}',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Items
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Beverage Items', style: AppTextStyles.heading5),
                    const SizedBox(height: 12),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.menuItemName,
                                    style: AppTextStyles.body1.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Qty: ${item.quantity}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.specialInstructions != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Note: ${item.specialInstructions}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              // Close Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

