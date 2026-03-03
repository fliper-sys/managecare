import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../providers/pharmacy_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';

class PharmacyExpiryScreen extends StatelessWidget {
  const PharmacyExpiryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final expiring = provider.expiringWithin(const Duration(days: 30));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Products'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (provider.usingLocalCache)
              Container(
                width: double.infinity,
                color: Colors.blue.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing cached data (offline or remote failed). Pull to refresh on the dashboard to retry.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: expiring.isEmpty
                  ? Center(
                      child: Text(
                        'No products expiring within 30 days',
                        style: AppTextStyles.body1,
                      ),
                    )
                  : ListView.separated(
                      itemCount: expiring.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final d = expiring[idx];
                        final expiry = DateFormat.yMMMMd().format(d.expiry.toLocal());
                        final daysLeft = d.expiry.difference(DateTime.now()).inDays;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.warning.withOpacity(0.12),
                            child: Text('${d.stock}'),
                          ),
                          title: Text(d.name),
                          subtitle: Text('Batch: ${d.batch} • Expiry: $expiry • In $daysLeft days'),
                          trailing: Text('${d.stock}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
