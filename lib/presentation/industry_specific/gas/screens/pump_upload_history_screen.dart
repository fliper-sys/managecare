import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../utils/pump_config_cache.dart';

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
  List<Map<String, dynamic>> _cachedPumps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCachedPumps());
  }

  CollectionReference<Map<String, dynamic>>? _collection(String name) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection(name);
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

  void _syncCacheFromSnapshot(
    String businessId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final remotePumps = PumpConfigCache.sort(
      docs.map(PumpConfigCache.fromDoc).toList(),
    );
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

  List<Map<String, String>> _pumpFilterOptions({
    required List<Map<String, dynamic>> pumpEntries,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> uploadDocs,
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

    for (final doc in uploadDocs) {
      final data = doc.data();
      addOption(
        pumpId: data['pumpId']?.toString() ?? '',
        pumpNumber: data['pumpNumber']?.toString() ?? '',
        productName: data['productName']?.toString() ?? 'Fuel',
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

  Future<void> _deleteUpload(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
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
      await doc.reference.delete();
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

  @override
  Widget build(BuildContext context) {
    final pumps = _collection('pump_configurations');
    final uploads = _collection('pump_daily_uploads');
    final role = WorkerPermissions.normalizeRole(
      context.watch<AuthProvider>().currentUser?.role ?? '',
    );
    final isOwner =
        context.watch<AuthProvider>().currentUser?.isOwner == true;
    final mustFilterOnePump = role == 'pump_operator';
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: const Text('Pump Upload History')),
      body: pumps == null || uploads == null
          ? const Center(child: Text('No business selected'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: pumps
                            .where('isActive', isEqualTo: true)
                            .orderBy('pumpNumber')
                            .snapshots(includeMetadataChanges: true),
                        builder: (context, snapshot) {
                          final pumpDocs = snapshot.data?.docs ?? [];
                          final businessId = context.read<BusinessProvider>().currentBusiness?.id;
                          if (businessId != null && businessId.isNotEmpty) {
                            _syncCacheFromSnapshot(businessId, pumpDocs);
                          }
                          final remotePumps = PumpConfigCache.sort(
                            pumpDocs.map(PumpConfigCache.fromDoc).toList(),
                          );
                          final availablePumps = remotePumps.isNotEmpty
                              ? remotePumps
                              : _cachedPumps;
                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: uploads
                                .orderBy('uploadedAt', descending: true)
                                .limit(200)
                                .snapshots(includeMetadataChanges: true),
                            builder: (context, uploadSnapshot) {
                              final uploadDocs =
                                  uploadSnapshot.data?.docs ?? [];
                              final pumpOptions = _pumpFilterOptions(
                                pumpEntries: availablePumps,
                                uploadDocs: uploadDocs,
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
                          const SizedBox(width: 8),
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
                      final uploadStream = _uploadStream(uploads);
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        key: ValueKey(
                          '${_selectedPumpId ?? ''}|'
                          '${_startDate?.millisecondsSinceEpoch ?? ''}|'
                          '${_endDate?.millisecondsSinceEpoch ?? ''}',
                        ),
                        stream: uploadStream,
                        builder: (context, snapshot) {
                          if (mustFilterOnePump &&
                              (_selectedPumpId == null ||
                                  _selectedPumpId!.isEmpty)) {
                            return const Center(
                              child: Text('Select one pump to view uploads'),
                            );
                          }
                          final docs = (snapshot.data?.docs ?? [])
                              .where((doc) => _matchesSelectedPump(doc.data()))
                              .toList();
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              docs.isEmpty) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (docs.isEmpty) {
                            return const Center(child: Text('No pump uploads yet'));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final uploadedAt = data['uploadedAt'] is Timestamp
                                  ? (data['uploadedAt'] as Timestamp).toDate()
                                  : null;
                              final openingUrl = data['openingPhotoUrl'] as String?;
                              final closingUrl = data['closingPhotoUrl'] as String?;
                              final shiftOpeningCashUrl = data['shiftOpeningCashPhotoUrl'] as String?;
                              final shiftCloseCashUrl = data['shiftCloseCashPhotoUrl'] as String?;
                              final shiftOpeningCash = data['shiftOpeningCash'];
                              final shiftCloseCash = data['shiftCloseCash'];
                              return Card(
                                child: ExpansionTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.upload_file_rounded),
                                  ),
                                  title: Text(
                                    'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? ''}',
                                  ),
                                  subtitle: Text(
                                    uploadedAt == null
                                        ? 'Operator: ${data['workerName'] ?? 'N/A'}'
                                        : DateFormat.yMd().add_jm().format(uploadedAt) + '\nOperator: ${data['workerName'] ?? 'N/A'}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${((data['soldVolume'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}',
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
                                        '${((data['expectedAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
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
                                            'Opening Volume: ${((data['openingVolume'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Closing Volume: ${((data['closingVolume'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}',
                                          ),
                                          const SizedBox(height: 4),
                                          if (shiftOpeningCash != null)
                                            Text(
                                              'Shift opening cash: ${_readCurrencyValue(shiftOpeningCash)}',
                                            ),
                                          if (shiftCloseCash != null)
                                            Text(
                                              'Shift close cash: ${_readCurrencyValue(shiftCloseCash)}',
                                            ),
                                          const SizedBox(height: 4),
                                          if (data['analogClosingVolume'] != null)
                                            Text(
                                              'Analog closing: ${((data['analogClosingVolume'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}',
                                            ),
                                          const SizedBox(height: 8),
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
                                          if (isOwner)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _deleteUpload(docs[index]),
                                                  icon: const Icon(Icons.delete),
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _uploadStream(
    CollectionReference<Map<String, dynamic>> uploads,
  ) {
    Query<Map<String, dynamic>> query = uploads;
    if (_startDate != null) {
      query = query.where(
        'uploadedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
      );
    }
    if (_endDate != null) {
      query = query.where(
        'uploadedAt',
        isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
      );
    }
    return query
        .orderBy('uploadedAt', descending: true)
        .limit(200)
        .snapshots(includeMetadataChanges: true);
  }
}
