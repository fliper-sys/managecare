import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/colors.dart';

class ExpiryTrackerScreen extends StatefulWidget {
  const ExpiryTrackerScreen({super.key});

  @override
  State<ExpiryTrackerScreen> createState() => _ExpiryTrackerScreenState();
}

class _ExpiryTrackerScreenState extends State<ExpiryTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PharmacyProvider>();
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        provider.loadFromRepository(businessId: business.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiry & Inventory Tracker'),
        backgroundColor: AppColors.pharmacy,
        elevation: 0,
      ),
      body: Consumer<PharmacyProvider>(
        builder: (context, provider, child) {
          final allDrugs = provider.drugs;
          final expiringDrugs = provider.getExpiringDrugs(daysThreshold: 30);
          final expiredDrugs = provider.getExpiredDrugs();
          final lowStockDrugs = provider.getLowStockDrugs(threshold: 5);

          // Build notifications summary
          final notifications = <Map<String, dynamic>>[];

          for (final drug in expiredDrugs) {
            notifications.add({
              'type': 'expired',
              'severity': 'critical',
              'drug': drug,
              'message': '${drug.name} has expired',
              'action': 'Remove from inventory',
            });
          }

          for (final drug in expiringDrugs) {
            final daysUntilExpiry =
                drug.expiry.difference(DateTime.now()).inDays;
            if (daysUntilExpiry <= 7) {
              notifications.add({
                'type': 'expiring',
                'severity': 'high',
                'drug': drug,
                'message': '${drug.name} expires in $daysUntilExpiry days',
                'action': 'Review stock levels',
              });
            } else {
              notifications.add({
                'type': 'expiring',
                'severity': 'medium',
                'drug': drug,
                'message': '${drug.name} expires in $daysUntilExpiry days',
                'action': 'Plan for rotation',
              });
            }
          }

          for (final drug in lowStockDrugs) {
            if (drug.stock == 0) {
              notifications.add({
                'type': 'out_of_stock',
                'severity': 'critical',
                'drug': drug,
                'message': '${drug.name} is OUT OF STOCK',
                'action': 'Reorder immediately',
              });
            } else {
              notifications.add({
                'type': 'low_stock',
                'severity': 'high',
                'drug': drug,
                'message': '${drug.name} has low stock (${drug.stock} units)',
                'action': 'Reorder soon',
              });
            }
          }

          // Sort by severity
          final severityOrder = {'critical': 0, 'high': 1, 'medium': 2};
          notifications.sort((a, b) => (severityOrder[a['severity']] ?? 3)
              .compareTo(severityOrder[b['severity']] ?? 3));

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle,
                      size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text('All inventory is healthy!',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '${allDrugs.length} total drugs in stock',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final drug = notif['drug'] as Drug;
              final severity = notif['severity'] as String;

              Color bgColor, textColor, iconColor;
              IconData icon;

              if (severity == 'critical') {
                bgColor = Colors.red.shade50;
                textColor = Colors.red.shade900;
                iconColor = Colors.red;
                icon = Icons.warning;
              } else if (severity == 'high') {
                bgColor = Colors.orange.shade50;
                textColor = Colors.orange.shade900;
                iconColor = Colors.orange;
                icon = Icons.info;
              } else {
                bgColor = Colors.yellow.shade50;
                textColor = Colors.yellow.shade900;
                iconColor = Colors.amber;
                icon = Icons.schedule;
              }

              return Card(
                color: bgColor,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: iconColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  drug.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['message'] as String,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Batch: ${drug.batch}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                    )),
                                Text(
                                  'Expiry: ${drug.expiry.toString().split(' ')[0]}',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Stock: ${drug.stock} units',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: severity == 'critical'
                                      ? Colors.red
                                      : severity == 'high'
                                          ? Colors.orange
                                          : Colors.amber,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  severity.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Action: ${notif['action']}',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (notif['type'] == 'expired' ||
                          (notif['type'] == 'out_of_stock'))
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text('Remove from Inventory'),
                                onPressed: () async {
                                  await Provider.of<PharmacyProvider>(context,
                                          listen: false)
                                      .removeExpiredDrugs();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Drug removed from inventory')),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      else if (notif['type'] == 'low_stock')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.shopping_cart),
                                label: const Text('Create Purchase Order'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Purchase order feature coming soon')),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text('Update Drug Info'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Update feature coming soon')),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

