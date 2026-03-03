import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  String _filterStatus = 'all'; // all, pending, dispensed, cancelled
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PharmacyProvider>();
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        provider.loadFromRepository(businessId: business.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = context.read<PharmacyProvider>();
              final business = context.read<BusinessProvider>().currentBusiness;
              if (business != null) {
                provider.loadFromRepository(businessId: business.id);
              }
            },
          ),
        ],
      ),
      body: Consumer<PharmacyProvider>(
        builder: (context, provider, child) {
          // Filter prescriptions by status
          var prescriptions = provider.prescriptions;
          if (_filterStatus != 'all') {
            prescriptions =
                prescriptions.where((p) => p.status == _filterStatus).toList();
          }

          // Apply text search if provided
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            prescriptions = prescriptions.where((p) {
              final patient = provider.patients
                  .cast<Patient?>()
                  .firstWhere((pt) => pt?.id == p.patientId, orElse: () => null);
              final pname = patient != null
                  ? patient.name
                  : ((p as dynamic).patientName as String?) ?? p.patientId;
              if (pname.toLowerCase().contains(q)) return true;
              if (p.id.toLowerCase().contains(q)) return true;
              final prescriber = (p as dynamic).prescriber as String?;
              if (prescriber != null && prescriber.toLowerCase().contains(q))
                return true;
              for (final it in p.items) {
                final drug = provider.drugs
                    .cast<Drug?>()
                    .firstWhere((d) => d?.id == it['drugId'], orElse: () => null);
                final dname = drug != null ? drug.name : (it['drugId'] as String);
                if (dname.toLowerCase().contains(q)) return true;
              }
              return false;
            }).toList();
          }

          if (prescriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No prescriptions',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search prescriptions (patient, id, drug, prescriber)...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              // Filter chips
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _filterStatus == 'all',
                        onSelected: (_) =>
                            setState(() => _filterStatus = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Pending'),
                        selected: _filterStatus == 'pending',
                        onSelected: (_) =>
                            setState(() => _filterStatus = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Dispensed'),
                        selected: _filterStatus == 'dispensed',
                        onSelected: (_) =>
                            setState(() => _filterStatus = 'dispensed'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Cancelled'),
                        selected: _filterStatus == 'cancelled',
                        onSelected: (_) =>
                            setState(() => _filterStatus = 'cancelled'),
                      ),
                    ],
                  ),
                ),
              ),
              // Prescription list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: prescriptions.length,
                  itemBuilder: (context, index) {
                    final p = prescriptions[index];
                    final patient = provider.patients
                        .cast<Patient?>()
                        .firstWhere((pt) => pt?.id == p.patientId,
                            orElse: () => null);
                    final patientName =
                        patient != null ? patient.name : p.patientId;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: _buildStatusBadge(p.status),
                        title: Text(patientName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${p.id}'),
                            Text('Date: ${p.createdAt.toString().split(' ')[0]}'),
                            Text('Items: ${p.items.length}'),
                            if ((p as dynamic).prescriber != null && (p as dynamic).prescriber!.isNotEmpty)
                              Text('Prescribed by: ${(p as dynamic).prescriber}'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _showPrescriptionDetails(context, p, provider),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green.shade700,
        onPressed: () => _showAddPrescriptionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule;
        break;
      case 'dispensed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _showPrescriptionDetails(
      BuildContext context, Prescription pres, PharmacyProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prescription ${pres.id}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDetailRow('Status', pres.status.toUpperCase()),
            _buildDetailRow('Date', pres.createdAt.toString().split(' ')[0]),
            _buildDetailRow('Items', '${pres.items.length} drugs'),
            const SizedBox(height: 16),
            const Text('Prescribed Drugs:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...pres.items.map((item) {
              final drug = provider.drugs.cast<Drug?>().firstWhere(
                  (d) => d?.id == item['drugId'],
                  orElse: () => null);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child:
                    Text('• ${drug?.name ?? 'Unknown'} - Qty: ${item['qty']}'),
              );
            }),
            const SizedBox(height: 16),
            if (pres.status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_pharmacy),
                      label: const Text('Dispense'),
                      onPressed: () {
                        // Persist dispense action with current user id
                        final auth = context.read<AuthProvider>();
                        final userId = auth.currentUser?.id;
                        provider.dispensePrescription(pres.id,
                            persist: true, userId: userId);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Prescription dispensed')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      onPressed: () {
                        // Persist cancellation and record the acting user
                        final auth = context.read<AuthProvider>();
                        final userId = auth.currentUser?.id;
                        provider.cancelPrescription(pres.id,
                            persist: true, userId: userId);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Prescription cancelled')),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddPrescriptionDialog(BuildContext context) {
    final provider = context.read<PharmacyProvider>();
    String? selectedPatientId;
    List<String> selectedDrugIds = [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Prescription'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Patient:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: selectedPatientId,
                hint: const Text('Choose a patient'),
                isExpanded: true,
                items: provider.patients.map((patient) {
                  return DropdownMenuItem(
                    value: patient.id,
                    child: Text(patient.name),
                  );
                }).toList(),
                onChanged: (value) {
                  // Dialog state would need StatefulBuilder for updates
                },
              ),
              const SizedBox(height: 16),
              const Text('Select Drugs:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...provider.drugs.map((drug) {
                return CheckboxListTile(
                  title: Text('${drug.name} (₦${drug.price})'),
                  subtitle: Text('Stock: ${drug.stock}'),
                  value: selectedDrugIds.contains(drug.id),
                  onChanged: (bool? value) {
                    // Would need StatefulBuilder for updates
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Only check for drugs since patient selection is optional
              if (selectedDrugIds.isNotEmpty) {
                final items = selectedDrugIds
                    .map((id) => {
                          'drugId': id,
                          'qty': 1,
                        })
                    .toList();

                provider.addPrescription(
                  selectedPatientId ?? '',
                  items,
                  persist: false,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription created')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

