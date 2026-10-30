import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/routes.dart';
import '../../../data/models/business_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/sales_repository_supabase.dart';

/// Shows the welcome-back summary once per dashboard entry unless this user
/// has opted out on this device.
Future<void> showWelcomeBackDialogIfEnabled({
  required BuildContext context,
  required UserModel user,
  required BusinessModel business,
}) async {
  if (!user.isOwner) return;

  final preferences = await SharedPreferences.getInstance();
  final preferenceKey = 'welcome_back_never_show_${user.id}';
  if (preferences.getBool(preferenceKey) == true || !context.mounted) return;

  Map<String, dynamic>? lastTransaction;
  try {
    final sales = await SalesRepositorySupabase().fetchSales(
      businessId: business.id,
      limit: 1,
    );
    if (sales.isNotEmpty) lastTransaction = sales.first;
  } catch (_) {
    // Keep the welcome experience available if transaction history is offline.
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _WelcomeBackDialog(
      user: user,
      business: business,
      lastTransaction: lastTransaction,
      preferences: preferences,
      preferenceKey: preferenceKey,
    ),
  );
}

class _WelcomeBackDialog extends StatefulWidget {
  final UserModel user;
  final BusinessModel business;
  final Map<String, dynamic>? lastTransaction;
  final SharedPreferences preferences;
  final String preferenceKey;

  const _WelcomeBackDialog({
    required this.user,
    required this.business,
    required this.lastTransaction,
    required this.preferences,
    required this.preferenceKey,
  });

  @override
  State<_WelcomeBackDialog> createState() => _WelcomeBackDialogState();
}

class _WelcomeBackDialogState extends State<_WelcomeBackDialog> {
  bool _neverShowAgain = false;

  Future<void> _setNeverShowAgain(bool value) async {
    setState(() => _neverShowAgain = value);
    await widget.preferences.setBool(widget.preferenceKey, value);
  }

  DateTime? _transactionDate() {
    final raw = widget.lastTransaction?['created_at'] ??
        widget.lastTransaction?['createdAt'] ??
        widget.lastTransaction?['date'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  double _transactionAmount() {
    final raw = widget.lastTransaction?['final_amount'] ??
        widget.lastTransaction?['finalAmount'] ??
        widget.lastTransaction?['total_amount'] ??
        widget.lastTransaction?['totalAmount'] ??
        widget.lastTransaction?['total'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${months[local.month - 1]} ${local.year} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transaction = widget.lastTransaction;
    final currency = (widget.business.currency ?? 'NGN').trim();
    final date = _transactionDate();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEEF4FF), Color(0xFFF8F5FF)],
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    SizedBox(
                      height: 148,
                      child: Lottie.asset(
                        'assets/lottie/onboard2.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome back to Manage Care',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF13213A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Good to see you again, ${widget.user.displayName}. Here’s a quick look at ${widget.business.name}.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: const Color(0xFF65718A),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'LAST TRANSACTION',
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF7A8498),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8EDF5)),
                      ),
                      child: transaction == null
                          ? const Row(
                              children: [
                                Icon(Icons.receipt_long_rounded,
                                    color: Color(0xFF71809A)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No transaction has been recorded yet.',
                                    style: TextStyle(
                                      color: Color(0xFF65718A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F7F1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Color(0xFF1A9B77),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$currency ${_transactionAmount().toStringAsFixed(2)}',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF18243B),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        date == null
                                            ? 'Recent business transaction'
                                            : _formatDate(date),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: const Color(0xFF738097),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF1A9B77)),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _setNeverShowAgain(!_neverShowAgain),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Checkbox.adaptive(
                              value: _neverShowAgain,
                              onChanged: (value) =>
                                  _setNeverShowAgain(value ?? false),
                              activeColor: const Color(0xFF2864E8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Never show this again',
                                style: TextStyle(
                                  color: Color(0xFF5E6A80),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context)
                            .pushNamed(Routes.advancedAnalytics);
                      },
                      icon: const Icon(Icons.insights_rounded),
                      label: const Text('Read more'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2864E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Maybe later'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
