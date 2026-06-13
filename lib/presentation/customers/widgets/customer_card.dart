import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/animated_lottie.dart';

class CustomerCard extends StatelessWidget {
  final String name;
  final String phone;
  final String totalPurchases;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const CustomerCard({
    super.key,
    required this.name,
    required this.phone,
    required this.totalPurchases,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: AnimatedLottie(
              asset: 'assets/lottie/woman-shopping-online.json',
              width: 28,
              height: 28,
              repeat: true,
            ),
          ),
        ),
        title: Text(name),
        subtitle: Text(phone),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total',
                    style: TextStyle(fontSize: 12, color: AppColors.darkGrey)),
                Text(totalPurchases,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete customer',
                onPressed: onDelete,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

