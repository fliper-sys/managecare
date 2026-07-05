import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/enhanced_subscription_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/business_model.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  static const Color _whatsappGreen = Color(0xFF25D366);
  static const Color _whatsappDark = Color(0xFF075E54);

  final _phoneNumberIdCtrl = TextEditingController();
  final _accessTokenCtrl = TextEditingController();
  final _ownerNumberCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final business = context.read<BusinessProvider>().currentBusiness;
    _loadFromBusiness(business);
  }

  void _loadFromBusiness(BusinessModel? b) {
    if (b == null) return;
    final settings = b.settings ?? {};
    _phoneNumberIdCtrl.text =
        (b.toJson()['whatsappPhoneNumberId'] as String?) ??
            (settings['whatsappPhoneNumberId'] as String?) ??
            '';
    _accessTokenCtrl.text = (b.toJson()['whatsappAccessToken'] as String?) ??
        (settings['whatsappAccessToken'] as String?) ??
        '';
    // support list of owner numbers
    if (settings['ownerWhatsappNumbers'] != null &&
        settings['ownerWhatsappNumbers'] is List) {
      final list = (settings['ownerWhatsappNumbers'] as List)
          .map((e) => e.toString())
          .toList();
      _ownerNumberCtrl.text = list.join(', ');
    } else {
      _ownerNumberCtrl.text = (b.toJson()['ownerWhatsappNumber'] as String?) ??
          (settings['ownerWhatsappNumber'] as String?) ??
          '';
    }
  }

  Future<void> _save() async {
    final businessProvider = context.read<BusinessProvider>();
    final current = businessProvider.currentBusiness;
    if (current == null) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final newSettings = Map<String, dynamic>.from(current.settings ?? {});
      newSettings['whatsappPhoneNumberId'] = _phoneNumberIdCtrl.text.trim();
      newSettings['whatsappAccessToken'] = _accessTokenCtrl.text.trim();
      // accept comma/newline separated list of numbers
      final raw = _ownerNumberCtrl.text.trim();
      if (raw.isEmpty) {
        newSettings.remove('ownerWhatsappNumbers');
        newSettings.remove('ownerWhatsappNumber');
      } else {
        final parts = raw
            .split(RegExp(r'[\,\n;]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.length == 1) {
          newSettings['ownerWhatsappNumber'] = parts.first;
          newSettings['ownerWhatsappNumbers'] = parts;
        } else {
          newSettings['ownerWhatsappNumbers'] = parts;
          newSettings.remove('ownerWhatsappNumber');
        }
      }

      final updated = current.copyWith(settings: newSettings);
      final ok = await businessProvider.updateBusiness(updated);

      setState(() => _saving = false);

      if (ok) {
        messenger.showSnackBar(const SnackBar(
            content: Text('WhatsApp settings saved'),
            backgroundColor: Colors.green));
      } else {
        messenger.showSnackBar(const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BusinessProvider, EnhancedSubscriptionProvider>(
      builder: (context, businessProvider, subProvider, _) {
        final business = businessProvider.currentBusiness;
        if (business == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('WhatsApp Settings')),
            body: const Center(child: Text('No business selected')),
          );
        }

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final userRole = auth.currentUser?.role;

        return FutureBuilder<bool>(
          future: subProvider.canAccessFeature(
              business: business,
              feature: 'api_access',
              context: 'whatsapp_settings_screen',
              userRole: userRole),
          builder: (context, snapshot) {
            final allowed = snapshot.data ?? false;
            if (snapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                  appBar: AppBar(title: const Text('WhatsApp Settings')),
                  body: const Center(child: CircularProgressIndicator()));
            }

            if (!allowed) {
              return Scaffold(
                appBar: AppBar(title: const Text('WhatsApp Settings')),
                body: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Upgrade Required',
                          style: AppTextStyles.heading4),
                      const SizedBox(height: 8),
                      const Text(
                          'WhatsApp configuration is available on higher subscription tiers. Upgrade this business subscription to access the feature.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                            context, '/subscription-status'),
                        child: const Text('Manage Subscription'),
                      )
                    ],
                  ),
                ),
              );
            }

            // allowed
            final scheme = Theme.of(context).colorScheme;
            return Scaffold(
              appBar: AppBar(
                title: const Text('WhatsApp Settings'),
                backgroundColor: _whatsappDark,
                foregroundColor: Colors.white,
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        _whatsappGreen.withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.18
                              : 0.12,
                        ),
                        scheme.surface,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _whatsappGreen.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: _whatsappGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WhatsApp Business',
                                style: AppTextStyles.heading4.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Connect Meta WhatsApp Cloud API credentials and owner recipients for automated business messages.',
                                style: AppTextStyles.caption.copyWith(
                                  color: scheme.onSurface.withOpacity(0.72),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cloud API credentials',
                            style: AppTextStyles.heading5.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _settingsField(
                            controller: _phoneNumberIdCtrl,
                            label: 'Phone Number ID',
                            hint: 'WhatsApp Phone Number ID',
                            icon: Icons.numbers_rounded,
                          ),
                          const SizedBox(height: 12),
                          _settingsField(
                            controller: _accessTokenCtrl,
                            label: 'Access Token',
                            hint: 'Meta access token',
                            icon: Icons.key_rounded,
                          ),
                          const SizedBox(height: 12),
                          _settingsField(
                            controller: _ownerNumberCtrl,
                            label: 'Owner WhatsApp Number(s)',
                            hint: '+2348012345678, +2348098765432',
                            icon: Icons.phone_rounded,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _whatsappGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Saving...' : 'Save WhatsApp Settings'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.notificationLogs),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('View Notification Logs'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                        context, Routes.thermalReceiptSettings),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Configure Thermal Receipt'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingsField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

