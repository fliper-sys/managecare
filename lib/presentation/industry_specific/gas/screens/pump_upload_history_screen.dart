import 'package:business_manager/presentation/industry_specific/gas/utils/pump_opening_cash_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_config_cache.dart';
import '../utils/pump_row_mapper.dart';
import 'disputed_pump_uploads_screen.dart';

class PumpUploadHistoryScreen extends StatefulWidget {
  const PumpUploadHistoryScreen({super.key});

  @override
  State<PumpUploadHistoryScreen> createState() =>
      _PumpUploadHistoryScreenState();
}

class _PumpUploadHistoryScreenState extends State<PumpUploadHistoryScreen> {
  String? _selectedPumpId;
  String? _selectedPumpNumber;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showMismatchBadge = true;
  List<Map<String, dynamic>> _cachedPumps = [];

  static const _pollInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCachedPumps());
  }

  Future<void> _loadCachedPumps() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    final cachedPumps = await PumpConfigCache.load(businessId);
    if (!mounted) return;
    setState(() {
      _cachedPumps = cachedPumps;
    });
  }

  void _syncCacheFromRows(String businessId, List<Map<String, dynamic>> rows) {
    final remotePumps = PumpConfigCache.sort(rows);
    if (remotePumps.isEmpty || PumpConfigCache.same(remotePumps, _cachedPumps)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PumpConfigCache.save(businessId, remotePumps);
      if (!mounted) return;
      setState(() {
        _cachedPumps = remotePumps;
      });
    });
  }

  Stream<List<Map<String, dynamic>>> _pumpsStream(String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance
            .get('/api/pumps/$businessId/pumps', query: {'isActive': 'true'});
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  Stream<List<Map<String, dynamic>>> _uploadsStream(String businessId) async* {
    while (true) {
      try {
        final query = <String, dynamic>{'limit': '200', 'isDisputed': 'false'};
        if (_startDate != null) query['from'] = _startDate!.toIso8601String();
        if (_endDate != null) query['to'] = _endDate!.toIso8601String();
        final response = await ManagecareApiClient.instance
            .get('/api/pumps/$businessId/uploads', query: query);
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpUploadRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  List<Map<String, String>> _pumpFilterOptions({
    required List<Map<String, dynamic>> pumpEntries,
    required List<Map<String, dynamic>> uploadRows,
  }) {
    final options = <Map<String, String>>[];
    final seen = <String>{};

    void addOption({
      required String pumpId,
      required String pumpNumber,
      required String productName,
    }) {
      final number = pumpNumber.trim();
      final id = pumpId.trim().isNotEmpty
          ? pumpId.trim()
          : number.isNotEmpty
              ? 'number:$number'
              : '';
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      options.add({
        'id': id,
        'pumpNumber': number,
        'productName': productName.trim(),
      });
    }

    for (final pump in pumpEntries) {
      addOption(
        pumpId: pump['id']?.toString() ?? '',
        pumpNumber: pump['pumpNumber']?.toString() ?? '',
        productName: pump['productName']?.toString() ?? 'Fuel',
      );
    }

    for (final row in uploadRows) {
      addOption(
        pumpId: row['pumpId']?.toString() ?? '',
        pumpNumber: row['pumpNumber']?.toString() ?? '',
        productName: row['productName']?.toString() ?? 'Fuel',
      );
    }

    options.sort((a, b) {
      final aNumber = double.tryParse(a['pumpNumber'] ?? '');
      final bNumber = double.tryParse(b['pumpNumber'] ?? '');
      if (aNumber != null && bNumber != null) {
        return aNumber.compareTo(bNumber);
      }
      return (a['pumpNumber'] ?? '').compareTo(b['pumpNumber'] ?? '');
    });
    return options;
  }

  String _readCurrencyValue(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', ''));
      if (parsed != null) {
        return parsed.toStringAsFixed(2);
      }
      return value;
    }
    return '0.00';
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0.0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _showImageDialog(String imageUrl, String label) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(label),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Unable to load image',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDiscrepancyDetails(Map<String, dynamic> data) async {
    if (!mounted) return;
    final openingVolume = (data['openingVolume'] as num?)?.toDouble() ?? 0;
    final closingVolume = (data['closingVolume'] as num?)?.toDouble() ?? 0;
    final previousClosingVolume = (data['previousClosingVolume'] as num?)?.toDouble();
    final analogOpeningVolume = (data['analogOpeningVolume'] as num?)?.toDouble();
    final analogClosingVolume = (data['analogClosingVolume'] as num?)?.toDouble() ?? 0;
    final previousAnalogClosingVolume = (data['previousAnalogClosingVolume'] as num?)?.toDouble();
    final previousShiftClosingCash = (data['previousShiftClosingCash'] as num?)?.toDouble();
    final soldVolume = (data['soldVolume'] as num?)?.toDouble() ?? 0;
    final shiftOpeningCash = data['shiftOpeningCash'];
    final shiftCloseCash = data['shiftCloseCash'];
    final todayPumpCash = (data['todayPumpCash'] as num?)?.toDouble() ??
        (data['cashAmount'] as num?)?.toDouble() ??
        0.0;
    final posAmount = (data['posAmount'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = todayPumpCash + posAmount;
    final expectedAmount = (data['expectedAmount'] as num?)?.toDouble() ??
        ((data['cashDerivedVolume'] as num?)?.toDouble() ?? 0);
    final volumeDifference = closingVolume - openingVolume;
    final discrepancySummary = (data['discrepancySummary'] as String?) ?? '';
    final openingCashDiff = calculateOpeningCashDifference(
      previousShiftClosingCash: previousShiftClosingCash,
      shiftOpeningCash: shiftOpeningCash,
    );
    final analogOpenDiff = analogOpeningVolume != null && previousAnalogClosingVolume != null
        ? analogOpeningVolume - previousAnalogClosingVolume
        : null;
    final openingVolumeDiff = previousClosingVolume != null
        ? openingVolume - previousClosingVolume
        : null;
    final shiftDifference = (double.tryParse(shiftCloseCash?.toString().replaceAll(',', '') ?? '') ?? 0.0) -
        (double.tryParse(shiftOpeningCash?.toString().replaceAll(',', '') ?? '') ?? 0.0);
    final shiftVolVsDigitalDiff = soldVolume - volumeDifference;
    final digitalVsAnalogDiff = volumeDifference - (analogClosingVolume - (analogOpeningVolume ?? 0));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Discrepancy details',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (discrepancySummary.isNotEmpty)
                    Text(
                      discrepancySummary,
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (discrepancySummary.isNotEmpty) const SizedBox(height: 16),
                  Text(
                    'Validation values',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (previousClosingVolume != null)
                    _buildDetailRow(
                      'Volume difference (previous closing vs new opening)',
                      '${openingVolumeDiff != null && openingVolumeDiff >= 0 ? '+' : ''}${formatAmount(openingVolumeDiff ?? 0.0, decimalDigits: 3)} L',
                    ),
                  if (openingCashDiff != null)
                    _buildDetailRow(
                      'Opening cash difference (previous shift close - new shift open)',
                      '${openingCashDiff >= 0 ? '+' : ''}${formatAmount(openingCashDiff, decimalDigits: 2)}',
                    ),
                  if (shiftOpeningCash != null && shiftCloseCash != null)
                    _buildDetailRow(
                      'Shift cash difference (close cash - opening cash)',
                      '${shiftDifference >= 0 ? '+' : ''}${formatAmount(shiftDifference, decimalDigits: 2)}',
                    ),
                  if (analogOpenDiff != null)
                    _buildDetailRow(
                      'Analog difference (previous closing vs new opening)',
                      '${analogOpenDiff >= 0 ? '+' : ''}${formatAmount(analogOpenDiff, decimalDigits: 3)} L',
                    ),
                  _buildDetailRow(
                    'Cash difference (expected amount vs total paid)',
                    '${(expectedAmount - totalPaid) >= 0 ? '+' : ''}${formatAmount(expectedAmount - totalPaid, decimalDigits: 2)}',
                  ),
                  _buildDetailRow(
                    'Shift vol vs digital volume difference',
                    '${shiftVolVsDigitalDiff >= 0 ? '+' : ''}${formatAmount(shiftVolVsDigitalDiff, decimalDigits: 3)} L',
                  ),
                  _buildDetailRow(
                    'Digital volume vs analog volume difference',
                    '${digitalVsAnalogDiff >= 0 ? '+' : ''}${formatAmount(digitalVsAnalogDiff, decimalDigits: 3)} L',
                  ),
                  _buildDetailRow(
                    'Shift cash vs total paid',
                    '${(shiftDifference - totalPaid) >= 0 ? '+' : ''}${formatAmount(shiftDifference - totalPaid, decimalDigits: 2)}',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.right),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      } else {
        _endDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
          999,
        );
      }
    });
  }

  void _clearDateFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  bool _matchesSelectedPump(Map<String, dynamic> data) {
    final selected = _selectedPumpId;
    if (selected == null || selected.isEmpty) return true;

    final selectedNumber = _selectedPumpNumber?.trim();
    final selectedId = selected.trim();
    final recordPumpId = data['pumpId']?.toString().trim();
    final recordPumpNumber = data['pumpNumber']?.toString().trim();

    if (selected.startsWith('number:')) {
      final pumpNumber = selected.substring('number:'.length).trim();
      return recordPumpNumber == pumpNumber;
    }

    if (selectedId.isNotEmpty && recordPumpId == selectedId) {
      return true;
    }

    if (selectedNumber != null && selectedNumber.isNotEmpty) {
      return recordPumpNumber == selectedNumber;
    }

    return false;
  }

  Future<void> _deleteUpload(String businessId, Map<String, dynamic> row) async {
    final isOwner = context.read<AuthProvider>().currentUser?.isOwner == true;
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the owner can delete uploads')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete upload'),
            content: const Text('Are you sure you want to delete this pump upload record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return;
      await ManagecareApiClient.instance.delete('/api/pumps/$businessId/uploads/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pump upload deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete upload: $error')),
      );
    }
  }

  Future<void> _markAsDisputed(
    String businessId,
    Map<String, dynamic> row,
  ) async {
    final reasonController = TextEditingController();
    bool confirmed;
    try {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Mark as disputed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This upload will move to the Disputed Uploads page until resolved.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Mark disputed'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;

      final auth = context.read<AuthProvider>().currentUser;
      final reason = reasonController.text.trim();
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return;
      try {
        await ManagecareApiClient.instance.patch(
          '/api/pumps/$businessId/uploads/$id/dispute',
          body: {
            'disputed_by': auth?.id,
            'disputed_by_name': auth?.fullName ?? auth?.email,
            if (reason.isNotEmpty) 'dispute_reason': reason,
          },
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload marked as disputed')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as disputed: $error')),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final role = WorkerPermissions.normalizeRole(
      context.watch<AuthProvider>().currentUser?.role ?? '',
    );
    final isOwner =
        context.watch<AuthProvider>().currentUser?.isOwner == true;
    final canManageDisputes =
        isOwner || WorkerPermissions.canManagePumpDisputes(role);
    final mustFilterOnePump = role == 'pump_operator';
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pump Upload History'),
        actions: [
          if (canManageDisputes)
            IconButton(
              tooltip: 'Disputed uploads',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DisputedPumpUploadsScreen(),
                ),
              ),
            ),
        ],
      ),
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('No business selected'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _pumpsStream(businessId),
                        builder: (context, snapshot) {
                          final pumpRows = snapshot.data ?? [];
                          if (pumpRows.isNotEmpty) {
                            _syncCacheFromRows(businessId, pumpRows);
                          }
                          final remotePumps = PumpConfigCache.sort(pumpRows);
                          final availablePumps = remotePumps.isNotEmpty
                              ? remotePumps
                              : _cachedPumps;
                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _uploadsStream(businessId),
                            builder: (context, uploadSnapshot) {
                              final uploadRows = uploadSnapshot.data ?? [];
                              final pumpOptions = _pumpFilterOptions(
                                pumpEntries: availablePumps,
                                uploadRows: uploadRows,
                              );
                              final selectedValue = pumpOptions.any(
                                (pump) => pump['id'] == _selectedPumpId,
                              )
                                  ? _selectedPumpId
                                  : null;
                              return DropdownButtonFormField<String>(
                                value: selectedValue,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by pump',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  if (!mustFilterOnePump)
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All pumps'),
                                    ),
                                  ...pumpOptions.map(
                                    (pump) => DropdownMenuItem<String>(
                                      value: pump['id'],
                                      child: Text(
                                        'Pump ${pump['pumpNumber']} - ${pump['productName']}',
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  Map<String, String>? selected;
                                  for (final pump in pumpOptions) {
                                    if (pump['id'] == value) {
                                      selected = pump;
                                      break;
                                    }
                                  }
                                  setState(() {
                                    _selectedPumpId = value;
                                    _selectedPumpNumber =
                                        selected?['pumpNumber'];
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isStart: true),
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                _startDate == null
                                    ? 'From date'
                                    : dateFormat.format(_startDate!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Show mismatch badges'),
                          Switch(
                            value: _showMismatchBadge,
                            onChanged: (value) {
                              setState(() {
                                _showMismatchBadge = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isStart: false),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                _endDate == null
                                    ? 'To date'
                                    : dateFormat.format(_endDate!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (_startDate != null || _endDate != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Clear dates',
                              onPressed: _clearDateFilters,
                              icon: const Icon(Icons.clear),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        key: ValueKey(
                          '${_selectedPumpId ?? ''}|'
                          '${_startDate?.millisecondsSinceEpoch ?? ''}|'
                          '${_endDate?.millisecondsSinceEpoch ?? ''}',
                        ),
                        stream: _uploadsStream(businessId),
                        builder: (context, snapshot) {
                          if (mustFilterOnePump &&
                              (_selectedPumpId == null ||
                                  _selectedPumpId!.isEmpty)) {
                            return const Center(
                              child: Text('Select one pump to view uploads'),
                            );
                          }
                          final rows = (snapshot.data ?? [])
                              .where((data) =>
                                  _matchesSelectedPump(data) &&
                                  data['isDisputed'] != true)
                              .toList();
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              rows.isEmpty) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (rows.isEmpty) {
                            return const Center(child: Text('No pump uploads yet'));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final data = rows[index];
                              final uploadedAt = _readDate(data['uploadedAt']);
                              final openingUrl = data['openingPhotoUrl'] as String?;
                              final closingUrl = data['closingPhotoUrl'] as String?;
                              final shiftOpeningCashUrl = data['shiftOpeningCashPhotoUrl'] as String?;
                              final shiftCloseCashUrl = data['shiftCloseCashPhotoUrl'] as String?;
                              final shiftOpeningCash = data['shiftOpeningCash'];
                              final shiftCloseCash = data['shiftCloseCash'];
                              final digitalOpeningVolume =
                                  _readDouble(data['openingVolume']);
                              final digitalClosingVolume =
                                  _readDouble(data['closingVolume']);
                              final analogOpeningVolume =
                                  _readDouble(data['analogOpeningVolume']);
                              final analogClosingVolume =
                                  _readDouble(data['analogClosingVolume']);
                              final todayPumpCash =
                                  _readDouble(data['todayPumpCash']) > 0
                                      ? _readDouble(data['todayPumpCash'])
                                      : _readDouble(data['cashAmount']);
                              final posAmount = _readDouble(data['posAmount']);
                              final recordedTotalPaid =
                                  _readDouble(data['totalPaid']);
                              final totalPaid = recordedTotalPaid > 0
                                  ? recordedTotalPaid
                                  : todayPumpCash + posAmount;
                              final saleId = data['saleId']?.toString() ?? '';
                              final soldVolume =
                                  _readDouble(data['soldVolume']) > 0
                                      ? _readDouble(data['soldVolume'])
                                      : _readDouble(data['cashDerivedVolume']) > 0
                                          ? _readDouble(data['cashDerivedVolume'])
                                          : digitalClosingVolume -
                                              digitalOpeningVolume;
                              final volumeDifference =
                                  digitalClosingVolume - digitalOpeningVolume;
                              final discrepancyNotes =
                                  (data['discrepancyNotes'] as List?)
                                      ?.whereType<String>()
                                      .toList() ??
                                  <String>[];
                              final discrepancySummary =
                                  (data['discrepancySummary'] as String?) ??
                                  '';
                              final theme = Theme.of(context);
                              final colorScheme = theme.colorScheme;
                              final hasMismatch = _showMismatchBadge &&
                                  (discrepancySummary.isNotEmpty || discrepancyNotes.isNotEmpty);
                              return Card(
                                child: ExpansionTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.upload_file_rounded),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? ''}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (hasMismatch)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Mismatch',
                                            style: TextStyle(
                                              color: Colors.amber.shade900,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    uploadedAt == null
                                        ? 'Operator: ${data['workerName'] ?? 'N/A'}'
                                        : '${DateFormat.yMd().add_jm().format(uploadedAt)}\nOperator: ${data['workerName'] ?? 'N/A'}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatAmount(
                                          soldVolume,
                                          decimalDigits: 3,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'Sold vol.',
                                        style: TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatAmount(
                                          ((data['expectedAmount'] as num?)?.toDouble() ?? 0),
                                          decimalDigits: 2,
                                        ),
                                      ),
                                      const Text(
                                        'Expected amount',
                                        style: TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Digital opening volume: ${formatAmount(digitalOpeningVolume, decimalDigits: 3)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Digital closing volume: ${formatAmount(digitalClosingVolume, decimalDigits: 3)}',
                                          ),
                                          const SizedBox(height: 4),
                                          if (shiftOpeningCash != null)
                                            Text(
                                              'Shift opening cash: ${_readCurrencyValue(shiftOpeningCash)}',
                                            ),
                                          if (shiftCloseCash != null)
                                            Text(
                                              'Shift closing cash: ${_readCurrencyValue(shiftCloseCash)}',
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Analog opening volume: ${formatAmount(analogOpeningVolume, decimalDigits: 3)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Analog closing volume: ${formatAmount(analogClosingVolume, decimalDigits: 3)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Sold volume: ${formatAmount(soldVolume, decimalDigits: 3)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Expected cash: ${formatAmount(((data['expectedAmount'] as num?)?.toDouble() ?? 0), decimalDigits: 2)}',
                                          ),
                                          if (todayPumpCash > 0)
                                            Text(
                                              'Pump cash: ${_readCurrencyValue(todayPumpCash)}',
                                            ),
                                          if (posAmount > 0)
                                            Text(
                                              'Pos amount: ${_readCurrencyValue(posAmount)}',
                                            ),
                                          if (totalPaid > 0)
                                            Text(
                                              'Total paid: ${_readCurrencyValue(totalPaid)}',
                                            ),
                                          if (saleId.isNotEmpty)
                                            Text(
                                              'Sales Id: $saleId',
                                            ),
                                          const SizedBox(height: 8),
                                          if (discrepancySummary.isNotEmpty)
                                            GestureDetector(
                                              onTap: () => _showDiscrepancyDetails(data),
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(10),
                                                margin: const EdgeInsets.only(bottom: 8),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.secondaryContainer,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: colorScheme.outlineVariant,
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.info_outline,
                                                      size: 18,
                                                      color: colorScheme.onSecondaryContainer,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        discrepancySummary,
                                                        style: TextStyle(
                                                          color: colorScheme.onSecondaryContainer,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      Icons.chevron_right,
                                                      size: 18,
                                                      color: colorScheme.onSecondaryContainer,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (discrepancyNotes.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: discrepancyNotes
                                                    .map(
                                                      (note) => Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: colorScheme.surfaceContainerHighest,
                                                          borderRadius: BorderRadius.circular(999),
                                                          border: Border.all(
                                                            color: colorScheme.outlineVariant,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          note,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          if (shiftOpeningCashUrl != null && shiftOpeningCashUrl.isNotEmpty)
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Shift opening cash image'),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () => _showImageDialog(
                                                    shiftOpeningCashUrl,
                                                    'Shift opening cash image',
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      shiftOpeningCashUrl,
                                                      height: 160,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                                                        height: 160,
                                                        child: Center(
                                                          child: Text('Unable to load shift opening cash image'),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (shiftCloseCashUrl != null && shiftCloseCashUrl.isNotEmpty)
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 12),
                                                const Text('Shift close cash image'),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () => _showImageDialog(
                                                    shiftCloseCashUrl,
                                                    'Shift close cash image',
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      shiftCloseCashUrl,
                                                      height: 160,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                                                        height: 160,
                                                        child: Center(
                                                          child: Text('Unable to load shift close cash image'),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 12),
                                          if (openingUrl != null && openingUrl.isNotEmpty)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text('Closing image'),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () => _showImageDialog(
                                                    openingUrl,
                                                    'Closing image',
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    child: Image.network(
                                                      openingUrl,
                                                      height: 160,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (context, error, stackTrace) =>
                                                              const SizedBox(
                                                        height: 160,
                                                        child: Center(
                                                          child: Text('Unable to load opening image'),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (closingUrl != null && closingUrl.isNotEmpty)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 12),
                                                const Text('Opening image'),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () => _showImageDialog(
                                                    closingUrl,
                                                    'Opening image',
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    child: Image.network(
                                                      closingUrl,
                                                      height: 160,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (context, error, stackTrace) =>
                                                              const SizedBox(
                                                        height: 160,
                                                        child: Center(
                                                          child: Text('Unable to load closing image'),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 12),
                                          if (canManageDisputes)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () =>
                                                      _markAsDisputed(
                                                          businessId, rows[index]),
                                                  icon: const Icon(
                                                      Icons.flag_outlined),
                                                  label: const Text(
                                                      'Mark as Disputed'),
                                                ),
                                                if (isOwner)
                                                  TextButton.icon(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.red,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteUpload(
                                                            businessId, rows[index]),
                                                    icon: const Icon(
                                                        Icons.delete),
                                                    label: const Text('Delete'),
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
