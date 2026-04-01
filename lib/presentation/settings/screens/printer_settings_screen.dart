import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../../services/thermal_printing_service.dart';
import '../../../services/thermal_printer_manager.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart' as text_styles;
import '../../../providers/settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';

/// Printer Settings Screen
/// Allows users to discover, connect, and test thermal printers
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late ThermalPrintingService _thermalService;
  List<ThermalPrinterDevice> _availablePrinters = [];
  ThermalPrinterDevice? _selectedPrinter;
  bool _isScanning = false;
  bool _isTesting = false;
  String? _statusMessage;
  Color? _statusColor;
  int _paperWidth = 58;

  @override
  void initState() {
    super.initState();
    _thermalService = ThermalPrintingService();
    _loadPrinterSettings();
  }

  void _loadPrinterSettings() async {
    try {
      await _thermalService.initialize();
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      
      setState(() {
        _paperWidth = int.tryParse(settings.paperWidth) ?? 58;
      });
      
      _discoverPrinters();
    } catch (e) {
      _showStatus('Error loading settings: $e', Colors.red);
    }
  }

  void _discoverPrinters() async {
    if (kIsWeb) {
      _showStatus('Printer discovery not available on web', Colors.orange);
      return;
    }

    setState(() => _isScanning = true);
    try {
      final printers = await _thermalService.getAvailablePrinters();
      setState(() {
        _availablePrinters = printers;
        _isScanning = false;
        if (printers.isEmpty) {
          _showStatus('No printers found', Colors.orange);
        } else {
          _showStatus('Found ${printers.length} printer(s)', Colors.green);
        }
      });
    } catch (e) {
      setState(() => _isScanning = false);
      _showStatus('Error discovering printers: $e', Colors.red);
    }
  }

  void _connectPrinter(ThermalPrinterDevice device) async {
    try {
      final success = await _thermalService.connectToPrinter(device);
      if (success) {
        setState(() => _selectedPrinter = device);
        _showStatus('Connected to ${device.name}', Colors.green);
        
        // Save selection
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
        final businessId = business?.id;
        final userId = auth.currentUser?.id;

        if (businessId == null || userId == null) {
          _showStatus(
            'Printer connected locally, but your settings could not be saved yet.',
            Colors.orange,
          );
          return;
        }

        await settings.updatePrinterSettings(
          businessId,
          userId,
          selectedPrinterMac: device.address,
          paperWidth: _paperWidth.toString(),
        );
      } else {
        _showStatus('Failed to connect to printer', Colors.red);
      }
    } catch (e) {
      _showStatus('Error connecting: $e', Colors.red);
    }
  }

  void _testPrinterConnection() async {
    if (_selectedPrinter == null) {
      _showStatus('Please select a printer first', Colors.orange);
      return;
    }

    setState(() => _isTesting = true);
    try {
      final result = await _thermalService.testPrinterConnection();
      setState(() => _isTesting = false);
      
      if (result.isSuccessful) {
        _showStatus(
          'Printer test successful!\nStatus: ${_thermalService.getStatusString(result.status)}',
          Colors.green,
        );
      } else {
        _showStatus(
          'Printer test failed!\nStatus: ${_thermalService.getStatusString(result.status)}',
          Colors.red,
        );
      }
    } catch (e) {
      setState(() => _isTesting = false);
      _showStatus('Error testing printer: $e', Colors.red);
    }
  }

  void _printTestReceipt() async {
    if (_selectedPrinter == null) {
      _showStatus('Please select a printer first', Colors.orange);
      return;
    }

    setState(() => _isTesting = true);
    try {
      // Step 1: Connect to printer first
      _showStatus('Connecting to printer...', Colors.blue);
      final connectSuccess = await _thermalService.connectToPrinter(_selectedPrinter!);
      
      if (!connectSuccess) {
        setState(() => _isTesting = false);
        _showStatus('Failed to connect to printer', Colors.red);
        return;
      }

      // Step 2: Generate test receipt
      _showStatus('Generating test receipt...', Colors.blue);
      final testReceipt = ThermalPrintingService.generateTestReceipt(
        paperWidth: _paperWidth,
      );
      
      // Step 3: Send test receipt
      _showStatus('Sending test receipt...', Colors.blue);
      final success = await _thermalService.printRawBytes(testReceipt);
      setState(() => _isTesting = false);
      
      if (success) {
        _showStatus('Test receipt sent to printer!', Colors.green);
      } else {
        _showStatus('Failed to send test receipt', Colors.red);
      }
    } catch (e) {
      setState(() => _isTesting = false);
      _showStatus('Error printing test receipt: $e', Colors.red);
    }
  }

  void _showStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
    
    // Auto-clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _statusMessage = null;
          _statusColor = null;
        });
      }
    });
  }

  void _changePaperWidth(int width) async {
    setState(() => _paperWidth = width);
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    final businessId = business?.id;
    final userId = auth.currentUser?.id;

    if (businessId == null || userId == null) {
      _showStatus(
        'Paper width updated for this session, but settings could not be saved yet.',
        Colors.orange,
      );
      return;
    }

    await settings.updatePrinterSettings(
      businessId,
      userId,
      paperWidth: width.toString(),
    );
    
    _showStatus('Paper width changed to ${width}mm', Colors.green);
  }

  void _previewTestReceipt() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;

    final receiptText = ThermalPrintingService.createCompleteReceipt(
      businessName: business?.name ?? 'TEST BUSINESS',
      paperWidth: _paperWidth,
      items: [
        {'name': 'Test Item A', 'quantity': 1, 'price': 120.0},
        {'name': 'Test Item B (Long name sample to wrap)', 'quantity': 2, 'price': 5.0},
      ],
      totalAmount: 130.0,
      paymentMethod: 'Cash',
      orderId: 'TEST-001',
      cashier: auth.currentUser?.fullName ?? 'Staff',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Receipt Preview'),
        content: SingleChildScrollView(
          child: SelectableText(
            receiptText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Trigger actual print flow
              _printTestReceipt();
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform info
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Thermal printing on web uses your system print dialog.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bluetooth, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Thermal printing on Android uses Bluetooth connection.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Status message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusColor!),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusColor == Colors.green
                          ? Icons.check_circle
                          : _statusColor == Colors.red
                              ? Icons.error
                              : Icons.info,
                      color: _statusColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(color: _statusColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Paper width selection
            Text(
              'Paper Width',
              style: text_styles.AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: RadioListTile<int>(
                      title: const Text('58mm'),
                      value: 58,
                      groupValue: _paperWidth,
                      onChanged: (value) => _changePaperWidth(value!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: RadioListTile<int>(
                      title: const Text('80mm'),
                      value: 80,
                      groupValue: _paperWidth,
                      onChanged: (value) => _changePaperWidth(value!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Printer discovery section (mobile only)
            if (!kIsWeb) ...[
              Text(
                'Available Printers',
                style: text_styles.AppTextStyles.heading3,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _discoverPrinters,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isScanning ? 'Scanning...' : 'Discover Printers'),
              ),
              const SizedBox(height: 12),
              if (_availablePrinters.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _isScanning
                          ? 'Scanning for printers...'
                          : 'No printers found. Make sure your printer is on and paired.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _availablePrinters.length,
                  itemBuilder: (context, index) {
                    final printer = _availablePrinters[index];
                    final isSelected = _selectedPrinter?.address == printer.address;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(printer.name),
                        subtitle: Text(printer.address),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () => _connectPrinter(printer),
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 24),

            // Selected printer info
            if (_selectedPrinter != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.print, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connected Printer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _selectedPrinter!.name,
                                  style: text_styles.AppTextStyles.heading3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Address: ${_selectedPrinter!.address}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Type: ${_selectedPrinter!.type}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Test buttons
            if (!kIsWeb)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: (_selectedPrinter == null || _isTesting)
                        ? null
                        : _testPrinterConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: (_selectedPrinter == null || _isTesting)
                        ? null
                        : _printTestReceipt,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(_isTesting ? 'Printing...' : 'Print Test Receipt'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _previewTestReceipt,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview Test Receipt'),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Info section
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Troubleshooting Tips',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Ensure your Bluetooth printer is turned on\n'
                      '• Make sure your printer is paired with your device\n'
                      '• If printer doesn\'t appear, try removing and re-pairing\n'
                      '• Test the connection before using in production\n'
                      '• Paper width affects receipt formatting',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
