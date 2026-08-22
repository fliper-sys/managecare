import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../services/customer_display_service.dart';

/// Configures the small customer-facing pole display some Windows POS
/// terminals have built in (the second screen on the back of the unit that
/// shows the running total to the person paying). Settings here are local
/// to this PC, not synced to the business - a COM port name only means
/// something on the machine it's plugged into.
class CustomerDisplaySettingsScreen extends StatefulWidget {
  const CustomerDisplaySettingsScreen({super.key});

  @override
  State<CustomerDisplaySettingsScreen> createState() =>
      _CustomerDisplaySettingsScreenState();
}

class _CustomerDisplaySettingsScreenState
    extends State<CustomerDisplaySettingsScreen> {
  final _service = CustomerDisplayService();

  bool _loading = true;
  bool _enabled = false;
  String? _selectedPort;
  int _baudRate = 9600;
  List<String> _ports = [];

  bool _isTesting = false;
  bool _isSaving = false;
  bool _isAutoDetecting = false;
  String? _statusMessage;
  Color? _statusColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _service.loadSettings();
      if (!mounted) return;
      setState(() {
        _enabled = settings.enabled;
        _selectedPort = settings.portName;
        _baudRate = settings.baudRate;
        _ports = _service.availablePorts();
        if (_selectedPort != null && !_ports.contains(_selectedPort)) {
          // Last-saved port isn't currently present (unplugged, different PC
          // restore, etc.) - keep it selectable so Save doesn't silently drop it.
          _ports = [..._ports, _selectedPort!];
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _selectedPort = null;
        _baudRate = 9600;
        _ports = _service.availablePorts();
        _statusMessage = 'Could not load saved customer display settings';
        _statusColor = Colors.orange;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _refreshPorts() {
    setState(() {
      _ports = _service.availablePorts();
      if (_selectedPort != null && !_ports.contains(_selectedPort)) {
        _ports = [..._ports, _selectedPort!];
      }
      _statusMessage = _ports.isEmpty
          ? 'No COM ports detected'
          : 'Found ${_ports.length} port(s)';
      _statusColor = _ports.isEmpty ? Colors.orange : Colors.green;
    });
  }

  Future<void> _testDisplay() async {
    if (_selectedPort == null) {
      setState(() {
        _statusMessage = 'Select a COM port first';
        _statusColor = Colors.orange;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = 'Connecting to $_selectedPort...';
      _statusColor = Colors.grey;
    });

    final connected = await _service.connect(
      portName: _selectedPort!,
      baudRate: _baudRate,
    );

    if (!connected) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _statusMessage =
            'Could not open $_selectedPort. Check it isn\'t in use by another app.';
        _statusColor = Colors.red;
      });
      return;
    }

    _service.showTotal(12500.00, currencySymbol: 'NGN');

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _statusMessage =
          'Sent a test total to the display. If it didn\'t show up, try a different baud rate.';
      _statusColor = Colors.green;
    });
  }

  Future<void> _persistCurrentSettings({bool reconnect = true}) async {
    await _service.saveSettings(CustomerDisplaySettings(
      enabled: _enabled,
      portName: _selectedPort,
      baudRate: _baudRate,
    ));

    if (reconnect) {
      if (_enabled && _selectedPort != null) {
        await _service.ensureConnectedFromSavedSettings();
      } else {
        _service.disconnect();
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _persistCurrentSettings();
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _statusMessage = 'Saved';
      _statusColor = Colors.green;
    });
  }

  Future<void> _autoDetect() async {
    setState(() {
      _isAutoDetecting = true;
      _statusMessage = 'Scanning COM ports and baud rates...';
      _statusColor = Colors.grey;
    });

    final result = await _service.autoDetectDisplay();
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _selectedPort = result.portName;
        _baudRate = result.baudRate;
        _statusMessage =
            'Detected display on ${result.portName} at ${result.baudRate} baud';
        _statusColor = Colors.green;
      });
    } else {
      setState(() {
        _statusMessage =
            'No customer display responded. Check the port and baud rate or reconnect the display.';
        _statusColor = Colors.orange;
      });
    }

    setState(() => _isAutoDetecting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!customerDisplaySupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Display')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The customer-facing pole display is a Windows POS terminal '
            'feature. It isn\'t available on this device.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Display')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Show the sale total to the customer on the terminal\'s '
                  'second screen as each sale completes.',
                  style: AppTextStyles.body2Secondary,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable customer display'),
                  value: _enabled,
                  onChanged: (v) {
                    setState(() => _enabled = v);
                    Future.microtask(() => _persistCurrentSettings());
                  },
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('COM Port', style: AppTextStyles.body1),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _isAutoDetecting ? null : _autoDetect,
                          icon: _isAutoDetecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.search, size: 18),
                          label: const Text('Auto detect'),
                        ),
                        TextButton.icon(
                          onPressed: _refreshPorts,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _selectedPort,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select a port',
                  ),
                  items: _ports
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedPort = v);
                    Future.microtask(
                      () => _persistCurrentSettings(reconnect: false),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Baud Rate', style: AppTextStyles.body1),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _baudRate,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: customerDisplayBaudRates
                      .map((b) => DropdownMenuItem(
                          value: b, child: Text('$b baud')))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _baudRate = v ?? 9600);
                    Future.microtask(
                      () => _persistCurrentSettings(reconnect: false),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Most of these displays default to 9600. If the test '
                  'below shows nothing, try another rate.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 20),
                if (_statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_statusColor ?? Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _statusColor ?? Colors.grey),
                    ),
                    child: Text(_statusMessage!, style: AppTextStyles.body2),
                  ),
                  const SizedBox(height: 16),
                ],
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testDisplay,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tv_outlined),
                  label: const Text('Send Test Total'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }
}
