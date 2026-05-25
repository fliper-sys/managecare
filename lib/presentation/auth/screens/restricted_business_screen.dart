import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/business_restriction_service.dart';
import '../../../widgets/custom_button.dart';

class RestrictedBusinessScreen extends StatelessWidget {
  final String businessName;
  final String restrictionReason;
  final String customerCareWhatsapp;

  const RestrictedBusinessScreen({
    super.key,
    required this.businessName,
    required this.restrictionReason,
    required this.customerCareWhatsapp,
  });

  Future<void> _openWhatsApp(BuildContext context) async {
    final supportPhone = customerCareWhatsapp.trim();
    if (supportPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support contact is not configured. Please contact admin.'),
        ),
      );
      return;
    }

    final service = BusinessRestrictionService();
    final url = service.buildWhatsAppUrl(
      supportPhone,
      message:
          'Hello, my business account for $businessName is restricted and I need support.',
    );

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 44,
                    ),
                  ),
                  Text(
                    'Business Access Restricted',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$businessName can sign in, but it cannot access business data or actions until admin restores the account.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reason',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          restrictionReason.trim().isEmpty
                              ? 'Your business is under admin review.'
                              : restrictionReason,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: customerCareWhatsapp.trim().isEmpty
                        ? 'Contact Admin Support'
                        : 'Contact Customer Care on WhatsApp',
                    onPressed: () => _openWhatsApp(context),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    customerCareWhatsapp.trim().isEmpty
                        ? 'Support contact is not configured for this business yet.'
                        : 'Support contact: $customerCareWhatsapp',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(Routes.splash);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check Access Again'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil(Routes.login, (_) => false);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
