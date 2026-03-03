import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/business_logic_provider.dart';
import '../../services/business_logic/pharmacy_logic.dart';

/// Pharmacy Inventory & Drug Management Screen
class PharmacyManagementScreen extends StatefulWidget {
  final String businessId;

  const PharmacyManagementScreen({
    required this.businessId,
    super.key,
  });

  @override
  State<PharmacyManagementScreen> createState() =>
      _PharmacyManagementScreenState();
}

class _PharmacyManagementScreenState extends State<PharmacyManagementScreen> {
  List<ExpiringMedication> _expiringMeds = [];
  List<DrugInteraction> _interactions = [];
  PrescriptionReport? _prescriptionReport;
  bool _isLoading = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadPharmacyData();
  }

  Future<void> _loadPharmacyData() async {
    setState(() => _isLoading = true);

    final provider = context.read<BusinessLogicProvider>();

    // Load all pharmacy data
    final expiringMeds = await provider.getExpiringMedications(30);
    final interactions = await provider
        .checkDrugInteractions(['aspirin', 'ibuprofen', 'warfarin']);
    final report = await provider.generatePrescriptionReport();

    setState(() {
      _expiringMeds = expiringMeds;
      _interactions = interactions;
      _prescriptionReport = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Management'),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab Navigation
                _buildTabBar(),
                // Content
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildExpiryTab(),
                      _buildInteractionsTab(),
                      _buildReportTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadPharmacyData,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          _buildTabButton('Expiry', 0),
          _buildTabButton('Interactions', 1),
          _buildTabButton('Report', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: isActive ? 14 : 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryTab() {
    if (_expiringMeds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('No medications expiring in 30 days'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expiringMeds.length,
      itemBuilder: (context, index) {
        final med = _expiringMeds[index];
        final daysUntilExpiry =
            med.expiryDate.difference(DateTime.now()).inDays;
        final isUrgent = daysUntilExpiry <= 7;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: isUrgent ? Colors.red.shade50 : Colors.white,
          child: ListTile(
            leading: Icon(
              Icons.warning,
              color: isUrgent ? Colors.red : Colors.orange,
            ),
            title: Text(
              med.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // batch number may not be available in the model; show stock and formatted expiry
                Text('Quantity: ${med.stock} units'),
                Text(
                    'Expires: ${med.expiryDate.toLocal().toIso8601String().split("T").first}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$daysUntilExpiry days',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isUrgent ? Colors.red.shade700 : Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractionsTab() {
    if (_interactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thumb_up, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('No drug interactions detected'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _interactions.length,
      itemBuilder: (context, index) {
        final interaction = _interactions[index];
        final severityColor = _getSeverityColor(interaction.severity);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: severityColor, width: 4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.05), blurRadius: 4),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${interaction.drug1Id} ↔ ${interaction.drug2Id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        interaction.severity.toUpperCase(),
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  interaction.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                // recommendation field not present in the current model; show guidance from description if needed
                Text(
                  'Guidance: ${interaction.description}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportTab() {
    if (_prescriptionReport == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final report = _prescriptionReport!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prescription Report Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Adapted to current PrescriptionReport model
                _buildReportStat(
                    'Total Prescriptions', '${report.totalPrescriptions}'),
                _buildReportStat(
                    'Total Revenue', report.totalRevenue.toStringAsFixed(2)),
                const SizedBox(height: 8),
                _buildReportStat('Period', report.period),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Medications',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Use `frequentDrugs` from the report model
                ...(report.frequentDrugs.entries.take(5).map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 12)),
                        Text(
                          '${e.value} prescriptions',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }
}

