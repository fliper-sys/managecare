import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/receipt_settings_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/thermal_printing_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';
import '../../settings/screens/subscription_screen.dart';

class ReceiptCustomizationScreen extends StatefulWidget {
  const ReceiptCustomizationScreen({super.key});

  @override
  State<ReceiptCustomizationScreen> createState() =>
      _ReceiptCustomizationScreenState();
}

class _ReceiptCustomizationScreenState
    extends State<ReceiptCustomizationScreen> {
  late TextEditingController _addressController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankNameController;
  late TextEditingController _dunningTriggerController;
  late TextEditingController _footerMessageController;
  late TextEditingController _headerNoteController;
  late TextEditingController _invoicePrefixController;
  bool _isProUser = false;
  bool _isSaving = false;
  late TextEditingController _phoneController;
  late TextEditingController _taxIdController;
  late TextEditingController _websiteController;
  late TextEditingController _accentColorController;

  // Visual style state
  String _stylePreset = 'professional';
  String _accentColorHex = '#2C3E50';

  @override
  void dispose() {
    _headerNoteController.dispose();
    _footerMessageController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _invoicePrefixController.dispose();
    _dunningTriggerController.dispose();
    _accentColorController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Receipt customization is available to all users now
    _isProUser = true;
    _initializeControllers();
  }

  // pro check removed — customization is available to all users

  void _initializeControllers() {
    final settings = context.read<ReceiptSettingsProvider>().receiptSettings;

    _headerNoteController =
        TextEditingController(text: settings?.headerNote ?? '');
    _footerMessageController =
        TextEditingController(text: settings?.footerMessage ?? '');
    _bankAccountController =
        TextEditingController(text: settings?.bankAccountNo ?? '');
    _bankNameController = TextEditingController(text: settings?.bankName ?? '');
    _addressController = TextEditingController(text: settings?.address ?? '');
    _phoneController = TextEditingController(text: settings?.phone ?? '');
    _websiteController = TextEditingController(text: settings?.website ?? '');
    _taxIdController = TextEditingController(text: settings?.taxId ?? '');
    _invoicePrefixController =
        TextEditingController(text: settings?.invoicePrefix ?? 'INV-');
    _dunningTriggerController =
        TextEditingController(text: settings?.dunningTriggerUrl ?? '');

    // Visual style defaults (from thermal preferences)
    final prefs = context.read<ReceiptSettingsProvider>().receiptPreferences;
    _stylePreset = prefs['stylePreset'] ?? _stylePreset;
    _accentColorHex = prefs['accentColor'] ?? _accentColorHex;
    _accentColorController = TextEditingController(text: _accentColorHex);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final receiptProvider = context.read<ReceiptSettingsProvider>();
      final business = context.read<BusinessProvider>().currentBusiness;

      if (business == null || receiptProvider.receiptSettings == null) {
        throw Exception('Business or receipt settings not found');
      }

      final updatedSettings = receiptProvider.receiptSettings!.copyWith(
        headerNote: _headerNoteController.text.isEmpty
            ? null
            : _headerNoteController.text,
        footerMessage: _footerMessageController.text.isEmpty
            ? null
            : _footerMessageController.text,
        bankAccountNo: _bankAccountController.text.isEmpty
            ? null
            : _bankAccountController.text,
        bankName:
            _bankNameController.text.isEmpty ? null : _bankNameController.text,
        address:
            _addressController.text.isEmpty ? null : _addressController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        website:
            _websiteController.text.isEmpty ? null : _websiteController.text,
        taxId: _taxIdController.text.isEmpty ? null : _taxIdController.text,
        invoicePrefix: _invoicePrefixController.text.isEmpty
            ? 'INV-'
            : _invoicePrefixController.text,
        dunningTriggerUrl: _dunningTriggerController.text.isEmpty
            ? null
            : _dunningTriggerController.text,
      );

      await receiptProvider.saveReceiptSettings(updatedSettings);

      // Persist visual style into thermal preferences
      String _sanitizeHex(String hex) {
        var h = hex.trim();
        if (!h.startsWith('#')) h = '#$h';
        if (!RegExp(r'^#([A-Fa-f0-9]{6})$').hasMatch(h)) h = '#2C3E50';
        return h.toUpperCase();
      }

      final sanitized = _sanitizeHex(_accentColorHex);

      await receiptProvider.updateReceiptPreferences({
        'stylePreset': _stylePreset,
        'accentColor': sanitized,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildToggleOption({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body2,
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String hex) {
    final isSelected = _accentColorHex.toLowerCase() == hex.toLowerCase();
    Color color;
    try {
      color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _accentColorHex = hex;
          _accentColorController.text = hex;
        });
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiptProvider = context.watch<ReceiptSettingsProvider>();
    final settings = receiptProvider.receiptSettings;

    if (receiptProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CustomLoadingIndicator()),
      );
    }

    if (!_isProUser) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Receipt Customization'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Pro Feature',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Receipt customization is available for Pro users only',
                  style: AppTextStyles.body2.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: CustomButton(
                    text: 'Upgrade to Pro',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Customization'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              'Customize Receipt Header',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Header Note',
              controller: _headerNoteController,
              hint: 'e.g., "Welcome to our store"',
              maxLines: 2,
              prefixIcon: Icons.notes,
            ),
            const SizedBox(height: 24),

            // Business Details Section
            Text(
              'Business Details',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Address',
              controller: _addressController,
              hint: 'Enter business address',
              prefixIcon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Phone',
              controller: _phoneController,
              hint: 'Enter phone number',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Website',
              controller: _websiteController,
              hint: 'e.g., www.example.com',
              prefixIcon: Icons.language,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Tax ID',
              controller: _taxIdController,
              hint: 'Enter tax identification number',
              prefixIcon: Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 24),

            // Banking Information Section
            Text(
              'Banking Information',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Bank Name',
              controller: _bankNameController,
              hint: 'Enter bank name',
              prefixIcon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Account Number',
              controller: _bankAccountController,
              hint: 'Enter account number',
              prefixIcon: Icons.numbers,
            ),
            const SizedBox(height: 24),

            // Receipt Options Section
            Text(
              'Receipt Options',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildToggleOption(
              label: 'Show Order ID',
              value: settings?.showOrderId ?? true,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'showOrderId',
                  value,
                );
              },
            ),
            _buildToggleOption(
              label: 'Show Date',
              value: settings?.showDate ?? true,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'showDate',
                  value,
                );
              },
            ),
            _buildToggleOption(
              label: 'Show Time',
              value: settings?.showTime ?? true,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'showTime',
                  value,
                );
              },
            ),
            _buildToggleOption(
              label: 'Show Payment Method',
              value: settings?.showPaymentMethod ?? true,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'showPaymentMethod',
                  value,
                );
              },
            ),
            _buildToggleOption(
              label: 'Show Cashier',
              value: settings?.showCashier ?? false,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'showCashier',
                  value,
                );
              },
            ),
            _buildToggleOption(
              label: 'Show Table Number (Restaurant)',
              value: settings?.showTableNo ?? false,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'showTableNo',
                  value,
                );
              },
            ),
            _buildToggleOption(
              label: 'Show Number of Persons (Restaurant)',
              value: settings?.showNumberOfPersons ?? false,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'showNumberOfPersons',
                  value,
                );
              },
            ),
            const SizedBox(height: 24),

            // Visual Style
            Text(
              'Visual Style',
              style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Style Preset', style: AppTextStyles.body2),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Minimal'),
                  selected: _stylePreset == 'minimal',
                  onSelected: (v) {
                    setState(() {
                      _stylePreset = 'minimal';
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Professional'),
                  selected: _stylePreset == 'professional',
                  onSelected: (v) {
                    setState(() {
                      _stylePreset = 'professional';
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Colorful'),
                  selected: _stylePreset == 'colorful',
                  onSelected: (v) {
                    setState(() {
                      _stylePreset = 'colorful';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Accent Color', style: AppTextStyles.body2),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildColorSwatch('#2C3E50'),
                const SizedBox(width: 8),
                _buildColorSwatch('#E74C3C'),
                const SizedBox(width: 8),
                _buildColorSwatch('#27AE60'),
                const SizedBox(width: 8),
                _buildColorSwatch('#F39C12'),
                const SizedBox(width: 8),
                _buildColorSwatch('#8E44AD'),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(
              label: 'Custom Color (hex, e.g., #2C3E50)',
              controller: _accentColorController,
              prefixIcon: Icons.color_lens,
              onChanged: (val) {
                setState(() {
                  _accentColorHex = val.trim();
                });
              },
            ),
            const SizedBox(height: 24),

            // Invoice Settings
            Text(
              'Invoice Settings',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildToggleOption(
              label: 'Enable Invoices',
              value: settings?.enableInvoices ?? false,
              onChanged: (value) async {
                await receiptProvider.updateReceiptSetting(
                  settings!.businessId,
                  'enableInvoices',
                  value,
                );
              },
            ),
            if (settings?.enableInvoices ?? false) ...[
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Invoice Prefix',
                controller: _invoicePrefixController,
                hint: 'e.g., INV-',
                prefixIcon: Icons.label_outlined,
              ),
            ],
            const SizedBox(height: 24),

            // Dunning trigger URL (Admin)
            Text(
              'Dunning Trigger URL',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CustomTextField(
              label: 'Dunning Trigger URL',
              controller: _dunningTriggerController,
              hint:
                  'e.g., https://your-server.com/emailtemplate/dunning_trigger.json',
              prefixIcon: Icons.link,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Footer Section
            Text(
              'Footer Message',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Footer Message',
              controller: _footerMessageController,
              hint: 'e.g., "Thank you for your purchase!"',
              maxLines: 2,
              prefixIcon: Icons.message_outlined,
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: CustomButton(
                text: _isSaving ? 'Saving...' : 'Save Settings',
                onPressed: _isSaving ? null : _saveSettings,
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                // Generate test receipt bytes for preview
                final testBytes = ThermalPrintingService.generateTestReceipt(
                  paperWidth: 58,
                );

                if (testBytes.isNotEmpty && mounted) {
                  // Show a message that preview is in test format
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preview: Test Receipt - Uses standard format'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.preview),
              label: const Text('Preview Receipt (Test Format)'),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

