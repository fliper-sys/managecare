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
                          'WhatsApp configuration is available to Professional and Enterprise plans. Upgrade your subscription to access this feature.'),
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
            return Scaffold(
              appBar: AppBar(title: const Text('WhatsApp Settings')),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('WhatsApp Phone Number ID',
                        style: AppTextStyles.body2),
                    const SizedBox(height: 6),
                    TextField(
                        controller: _phoneNumberIdCtrl,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'WhatsApp Phone Number ID')),
                    const SizedBox(height: 12),
                    const Text('WhatsApp Access Token',
                        style: AppTextStyles.body2),
                    const SizedBox(height: 6),
                    TextField(
                        controller: _accessTokenCtrl,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Access Token')),
                    const SizedBox(height: 12),
                    const Text('Owner WhatsApp Number',
                        style: AppTextStyles.body2),
                    const SizedBox(height: 6),
                    TextField(
                        controller: _ownerNumberCtrl,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '+2348012345678')),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(
                                context, Routes.notificationLogs),
                            child: const Text('View Notification Logs'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(
                                context, Routes.thermalReceiptSettings),
                            child: const Text('Configure Thermal Receipt'),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

