import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/datetime_utils.dart';
import '../../providers/admin_provider.dart';
import '../admin_theme.dart';

class RestrictedBusinessesPage extends StatelessWidget {
  const RestrictedBusinessesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: Consumer<AdminProvider>(
          builder: (context, admin, _) {
            final restricted = admin.allBusinesses.where((business) {
              final status = (business['restrictionStatus'] ??
                      business['status'] ??
                      '')
                  .toString()
                  .toLowerCase();
              return business['isRestricted'] == true ||
                  status == 'restricted' ||
                  status == 'suspended' ||
                  status == 'blocked';
            }).toList();

            return RefreshIndicator(
              onRefresh: () => admin.fetchAdminStats(force: true),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Restricted Accounts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.adminTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${restricted.length} businesses currently restricted',
                    style: TextStyle(color: context.adminTextSecondary),
                  ),
                  const SizedBox(height: 18),
                  if (admin.isLoading && restricted.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (restricted.isEmpty)
                    _emptyState(context)
                  else
                    ...restricted.map((business) => _restrictedCard(
                          context,
                          admin,
                          business,
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration:
          context.adminCardDecoration(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.verified_user_rounded,
              size: 42, color: context.adminTextTertiary),
          const SizedBox(height: 10),
          Text(
            'No restricted business accounts',
            style: TextStyle(
              color: context.adminTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _restrictedCard(
    BuildContext context,
    AdminProvider admin,
    Map<String, dynamic> business,
  ) {
    final reason = (business['restrictionReason'] ??
            business['restrictedReason'] ??
            business['suspensionReason'] ??
            'No reason recorded')
        .toString();
    final restrictedAt = business['restrictedAt'] ?? business['updatedAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration:
          context.adminCardDecoration(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_bad_rounded, color: Color(0xFFEF4444)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (business['name'] ?? 'Unknown business').toString(),
                  style: TextStyle(
                    color: context.adminTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: TextStyle(color: context.adminTextSecondary, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            'Restricted: ${_formatDate(restrictedAt)}',
            style: TextStyle(color: context.adminTextTertiary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                final ok = await admin.setBusinessRestriction(
                  businessId: (business['id'] ?? '').toString(),
                  restricted: false,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Business access restored'
                        : 'Unable to restore business'),
                  ),
                );
              },
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Restore'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Not recorded';
    try {
      final date = parseTimestamp(value);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      if (value is Timestamp) {
        final date = value.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return value.toString();
    }
  }
}
