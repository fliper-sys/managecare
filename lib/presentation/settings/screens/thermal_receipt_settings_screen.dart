import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/receipt_settings_provider.dart';
import '../../../providers/business_provider.dart';

/// Enhanced receipt customization screen for pro users
/// Allows customization of 58mm thermal printer receipts
class ThermalReceiptSettingsScreen extends StatefulWidget {
  const ThermalReceiptSettingsScreen({super.key});

  @override
  State<ThermalReceiptSettingsScreen> createState() =>
      _ThermalReceiptSettingsScreenState();
}

class _ThermalReceiptSettingsScreenState
    extends State<ThermalReceiptSettingsScreen> {
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountController;
  late TextEditingController _websiteController;
  late TextEditingController _customHeaderController;
  late TextEditingController _customFooterController;
  late TextEditingController _qrCodeTypeController;
  late TextEditingController _currencyController;
  late TextEditingController _receiptUrlController;
  late TextEditingController _copiesController;

  bool _showBankDetails = false;
  bool _showQrCode = false;
  bool _showQrImage = false;
  bool _enableQrImagePrinting = false;
  bool _compactLayout = false;
  String _fontSizeOption = 'medium';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final settingsProvider =
        Provider.of<ReceiptSettingsProvider>(context, listen: false);
    final prefs = settingsProvider.receiptPreferences;

    _bankNameController = TextEditingController(text: prefs['bankName'] ?? '');
    _bankAccountController =
        TextEditingController(text: prefs['bankAccount'] ?? '');
    _websiteController = TextEditingController(text: prefs['website'] ?? '');
    _customHeaderController =
        TextEditingController(text: prefs['customHeaderText'] ?? '');
    _customFooterController =
        TextEditingController(text: prefs['customFooterText'] ?? '');
    _qrCodeTypeController =
        TextEditingController(text: prefs['qrCodeType'] ?? 'url');
    _currencyController =
        TextEditingController(text: prefs['currencySymbol'] ?? '₦');
    _receiptUrlController =
        TextEditingController(text: prefs['receiptUrlBase'] ?? '');    _copiesController = TextEditingController(text: (prefs['copies'] ?? 2).toString());
    _showBankDetails = prefs['showBankDetails'] ?? false;
    _showQrCode = prefs['showQrCode'] ?? false;
    _showQrImage = prefs['showQrImage'] ?? false;
    _enableQrImagePrinting = prefs['enableQrImagePrinting'] ?? false;
    _compactLayout = prefs['compactLayout'] ?? false;
    _fontSizeOption = prefs['fontSize'] ?? 'medium';
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _websiteController.dispose();
    _customHeaderController.dispose();
    _customFooterController.dispose();
    _qrCodeTypeController.dispose();
    _currencyController.dispose();
    _receiptUrlController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final settingsProvider =
        Provider.of<ReceiptSettingsProvider>(context, listen: false);

    final updates = {
      'bankName': _bankNameController.text,
      'bankAccount': _bankAccountController.text,
      'website': _websiteController.text,
      'customHeaderText': _customHeaderController.text,
      'customFooterText': _customFooterController.text,
      'currencySymbol': _currencyController.text,
      'receiptUrlBase': _receiptUrlController.text,
      'qrCodeType': _qrCodeTypeController.text,
      'showBankDetails': _showBankDetails,
      'showQrCode': _showQrCode,
      'showQrImage': _showQrImage,
      'enableQrImagePrinting': _enableQrImagePrinting,
      'compactLayout': _compactLayout,
      'fontSize': _fontSizeOption,
      'copies': int.tryParse(_copiesController.text) ?? 2,
    };

    await settingsProvider.updateReceiptPreferences(updates);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt settings updated successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Receipt Settings'),
        elevation: 0,
      ),
      body: Consumer2<BusinessProvider, ReceiptSettingsProvider>(
        builder: (context, businessProvider, settingsProvider, _) {
          final business = businessProvider.currentBusiness;
          if (business == null) {
            return const Center(child: Text('No business selected'));
          }
          // Show the full customization UI for all users.
          // Ensure settings are loaded for the selected business.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            settingsProvider.fetchReceiptSettings(business.id);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header text
              _buildSectionHeader('Receipt Header'),
              _buildTextField(
                controller: _customHeaderController,
                label: 'Custom Header Text',
                hint: 'Enter text to display above receipt details',
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Font size options
              _buildSectionHeader('Print Layout'),
              _buildFontSizeSelector(),
              const SizedBox(height: 16),

              // Layout options
              CheckboxListTile(
                title: const Text('Compact Layout'),
                subtitle: const Text('Reduce spacing for more items per page'),
                value: _compactLayout,
                onChanged: (value) {
                  setState(() => _compactLayout = value ?? false);
                },
              ),
              const SizedBox(height: 24),

              // Bank details section
              _buildSectionHeader('Business Information'),
              CheckboxListTile(
                title: const Text('Show Bank Details'),
                subtitle: const Text('Display bank name and account number'),
                value: _showBankDetails,
                onChanged: (value) {
                  setState(() => _showBankDetails = value ?? false);
                },
              ),
              if (_showBankDetails) ...[
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _bankNameController,
                  label: 'Bank Name',
                  hint: 'e.g., First Bank of Nigeria',
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _bankAccountController,
                  label: 'Account Number',
                  hint: 'e.g., 0123456789',
                ),
              ],
              const SizedBox(height: 16),

              // Website
              _buildTextField(
                controller: _websiteController,
                label: 'Website',
                hint: 'e.g., www.yourbusiness.com',
              ),
              const SizedBox(height: 24),

              // QR Code option
              _buildSectionHeader('Additional Features'),
              CheckboxListTile(
                title: const Text('Show QR Code'),
                subtitle:
                    const Text('Display QR code on receipt (if supported)'),
                value: _showQrCode,
                onChanged: (value) {
                  setState(() => _showQrCode = value ?? false);
                },
              ),
              const SizedBox(height: 12),
              // Number of copies
              _buildTextField(
                controller: _copiesController,
                label: 'Number of receipt copies',
                hint: 'e.g., 2 (customer + business)',
              ),
              const SizedBox(height: 12),
              if (_showQrCode) ...[
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: 'QR Code Type',
                  value: _qrCodeTypeController.text,
                  items: ['url', 'order_id', 'vcard'],
                  onChanged: (value) {
                    _qrCodeTypeController.text = value ?? 'url';
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _receiptUrlController,
                  label: 'Receipt Base URL',
                  hint: 'https://example.com/receipt',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Print QR image on supported printers'),
                  subtitle: const Text(
                      'Try to send an actual QR image to compatible printers'),
                  value: _showQrImage,
                  onChanged: (v) => setState(() => _showQrImage = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Enable QR image printing (experimental)'),
                  subtitle: const Text(
                      'If the printer driver supports it, this will attempt to print a QR image'),
                  value: _enableQrImagePrinting,
                  onChanged: (v) => setState(() => _enableQrImagePrinting = v ?? false),
                ),
              ],
              const SizedBox(height: 24),

              // Footer text
              _buildSectionHeader('Receipt Footer'),
              _buildTextField(
                controller: _customFooterController,
                label: 'Custom Footer Text',
                hint: 'Enter text to display at bottom of receipt',
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Receipt Settings'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () {
                  // Show message that PDF preview requires custom implementation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF preview feature requires additional setup')),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Preview PDF'),
              ),

              const SizedBox(height: 16),

              // Preview section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Preview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        color: Colors.grey[100],
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            _generatePreview(),
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildFontSizeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Font Size',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['small', 'medium', 'large'].map((size) {
              return ChoiceChip(
                label: Text(size.capitalize()),
                selected: _fontSizeOption == size,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _fontSizeOption = size);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  String _generatePreview() {
    final header = _customHeaderController.text.isNotEmpty
        ? '${_customHeaderController.text}\n'
        : '';
    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    final location = business != null ? (business.address ?? (business.city != null ? '${business.city}${business.state != null && business.state!.isNotEmpty ? ', ' + business.state! : ''}' : '')) : '';

    final bankSection = _showBankDetails
        ? 'Bank: ${_bankNameController.text}\nAcct: ${_bankAccountController.text}${location.isNotEmpty ? '\nLocation: $location' : ''}\n'
        : '';
    final website = _websiteController.text.isNotEmpty
        ? 'Web: ${_websiteController.text}\n'
        : '';
    final footer = _customFooterController.text.isNotEmpty
        ? '\n${_customFooterController.text}'
        : '';

    return '''========================================
        YOUR BUSINESS NAME
========================================
SAMPLE RECEIPT PREVIEW

$header
Item Name..................Qty  Price Total
Widget......................  2   15.00  30.00
========================================
Subtotal:..............................  30.00
Tax:..................................   3.00
TOTAL:..............................   33.00
========================================
Payment: Cash

$bankSection$website
Thank you for your purchase!$footer
========================================''';
  }
}

extension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

