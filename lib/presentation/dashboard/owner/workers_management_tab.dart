import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';

class WorkersManagementTab extends StatefulWidget {
  const WorkersManagementTab({super.key});

  @override
  State<WorkersManagementTab> createState() => _WorkersManagementTabState();
}

class _WorkersManagementTabState extends State<WorkersManagementTab> {
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Stats
          Text(
            'Team Management',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _WorkerStatCard(
                  label: 'Total Staff',
                  value: '24',
                  icon: Icons.groups,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WorkerStatCard(
                  label: 'On Duty',
                  value: '18',
                  icon: Icons.check_circle,
                  color: AppColors.success,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WorkerStatCard(
                  label: 'On Leave',
                  value: '4',
                  icon: Icons.calendar_today,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter Status
          Text(
            'Status Filter',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'active', 'on_leave', 'inactive']
                  .map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status[0].toUpperCase() +
                              status.substring(1).replaceAll('_', ' ')),
                          selected: _filterStatus == status,
                          onSelected: (selected) {
                            setState(() => _filterStatus = status);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Workers List
          Text(
            'Staff Members',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const _WorkerCard(
            name: 'Chioma Adeyemi',
            position: 'Sales Associate',
            status: 'On Duty',
            statusColor: AppColors.success,
            joinDate: 'Jan 15, 2024',
            phone: '+234 701 234 5678',
            email: 'chioma@business.com',
          ),
          const SizedBox(height: 12),
          const _WorkerCard(
            name: 'Tunde Okafor',
            position: 'Store Manager',
            status: 'On Duty',
            statusColor: AppColors.success,
            joinDate: 'Dec 10, 2023',
            phone: '+234 702 345 6789',
            email: 'tunde@business.com',
          ),
          const SizedBox(height: 12),
          const _WorkerCard(
            name: 'Amara Eze',
            position: 'Cashier',
            status: 'On Leave',
            statusColor: AppColors.warning,
            joinDate: 'Feb 20, 2024',
            phone: '+234 703 456 7890',
            email: 'amara@business.com',
          ),
          const SizedBox(height: 12),
          const _WorkerCard(
            name: 'Oluwaseun Bello',
            position: 'Inventory Manager',
            status: 'On Duty',
            statusColor: AppColors.success,
            joinDate: 'Jan 5, 2024',
            phone: '+234 704 567 8901',
            email: 'oluwaseun@business.com',
          ),
          const SizedBox(height: 24),

          // Performance Metrics
          Text(
            'Top Performers',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const _PerformerCard(
            rank: 1,
            name: 'Chioma Adeyemi',
            salesThisMonth: '₦125,400',
            avgRating: 4.8,
            transactions: 234,
          ),
          const SizedBox(height: 8),
          const _PerformerCard(
            rank: 2,
            name: 'Oluwaseun Bello',
            salesThisMonth: '₦98,500',
            avgRating: 4.6,
            transactions: 189,
          ),
          const SizedBox(height: 8),
          const _PerformerCard(
            rank: 3,
            name: 'Tunde Okafor',
            salesThisMonth: '₦87,200',
            avgRating: 4.5,
            transactions: 156,
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Actions',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.24)),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add),
                  title: const Text('Add New Worker'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Add worker form coming soon')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment),
                  title: const Text('Assign Tasks'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Task assignment form coming soon')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Manage Shifts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Shift management coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _WorkerStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.heading5.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final String name;
  final String position;
  final String status;
  final Color statusColor;
  final String joinDate;
  final String phone;
  final String email;

  const _WorkerCard({
    required this.name,
    required this.position,
    required this.status,
    required this.statusColor,
    required this.joinDate,
    required this.phone,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.body2
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      position,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Joined: $joinDate',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(Icons.phone,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(Icons.mail,
                        size: 18, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformerCard extends StatelessWidget {
  final int rank;
  final String name;
  final String salesThisMonth;
  final double avgRating;
  final int transactions;

  const _PerformerCard({
    required this.rank,
    required this.name,
    required this.salesThisMonth,
    required this.avgRating,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rank == 1
                    ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                    : rank == 2
                        ? [const Color(0xFFC0C0C0), const Color(0xFF808080)]
                        : [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '$avgRating • $transactions sales',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            salesThisMonth,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

