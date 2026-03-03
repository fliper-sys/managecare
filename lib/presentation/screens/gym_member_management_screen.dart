import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/business_logic_provider.dart';
import '../../services/business_logic/gym_logic.dart';

/// Gym Member Management Screen
class GymMemberManagementScreen extends StatefulWidget {
  final String businessId;

  const GymMemberManagementScreen({
    required this.businessId,
    super.key,
  });

  @override
  State<GymMemberManagementScreen> createState() =>
      _GymMemberManagementScreenState();
}

class _GymMemberManagementScreenState extends State<GymMemberManagementScreen> {
  MembershipDetails? _memberDetails;
  BillingCycle? _billing;
  MemberEngagementAnalysis? _engagement;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    setState(() => _isLoading = true);

    final provider = context.read<BusinessLogicProvider>();

    // Load member details, billing, and engagement
    final details = await provider.getMembershipDetails('member-123');
    final billing =
        await provider.calculateMemberBilling('member-123', DateTime.now());
    final engagement = await provider.analyzeMemberEngagement('member-123', 3);

    setState(() {
      _memberDetails = details;
      _billing = billing;
      _engagement = engagement;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Management'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_memberDetails != null) _buildMemberCard(),
                  if (_engagement != null) _buildEngagementCard(),
                  if (_billing != null) _buildBillingCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadMemberData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildMemberCard() {
    final member = _memberDetails!;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.memberName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Membership', member.membershipType.toUpperCase()),
            _buildInfoRow('Email', member.email),
            _buildInfoRow('Phone', member.phone),
            _buildInfoRow(
                'Monthly Cost', '\$${member.monthlyCost.toStringAsFixed(2)}'),
            _buildInfoRow('Status', member.status),
            const SizedBox(height: 12),
            Text(
              'Classes: ${member.classesPerMonth}/month | PT Sessions: ${member.personalTrainerSessions}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementCard() {
    final engagement = _engagement!;
    final scoreColor =
        engagement.engagementScore >= 70 ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Member Engagement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEngagementMetric(
                  'Score',
                  '${engagement.engagementScore}/100',
                  scoreColor,
                ),
                _buildEngagementMetric(
                  'Check-ins',
                  '${engagement.totalCheckIns}',
                  Colors.blue,
                ),
                _buildEngagementMetric(
                  'Classes',
                  '${engagement.classesAttended}',
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: engagement.retentionStatus == 'active'
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Status: ${engagement.retentionStatus} (Last check-in: ${engagement.daysSinceLastCheckIn} days ago)',
                style: TextStyle(
                  fontSize: 12,
                  color: engagement.retentionStatus == 'active'
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingCard() {
    final billing = _billing!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billing Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildBillingItem('Base Membership',
                '\$${billing.baseMonthlyCost.toStringAsFixed(2)}'),
            if (billing.personalTrainingCharges > 0)
              _buildBillingItem(
                'PT Sessions (${billing.ptSessionsAttended})',
                '\$${billing.personalTrainingCharges.toStringAsFixed(2)}',
              ),
            if (billing.additionalClassCharges > 0)
              _buildBillingItem(
                'Extra Classes',
                '\$${billing.additionalClassCharges.toStringAsFixed(2)}',
              ),
            const Divider(height: 16),
            _buildBillingItem(
              'Total',
              '\$${billing.totalBilling.toStringAsFixed(2)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBillingItem(String label, String amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.blue.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

