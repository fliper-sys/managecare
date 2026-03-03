import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/loyalty_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/custom_app_bar.dart';

class LoyaltyDashboardScreen extends StatefulWidget {
  const LoyaltyDashboardScreen({super.key});

  @override
  State<LoyaltyDashboardScreen> createState() => _LoyaltyDashboardScreenState();
}

class _LoyaltyDashboardScreenState extends State<LoyaltyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Loyalty Program',
        showBackButton: true,
      ),
      body: Consumer<LoyaltyProvider>(
        builder: (context, provider, _) {
          if (provider.currentMember == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.card_giftcard,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Member Data',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please select a customer first',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                        ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Member Tier Card
              _buildTierCard(context, provider),
              const SizedBox(height: 16),
              // Points Summary
              _buildPointsSummary(context, provider),
              const SizedBox(height: 16),
              // Tab Navigation
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Rewards'),
                  Tab(text: 'History'),
                ],
              ),
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, provider),
                    _buildRewardsTab(context, provider),
                    _buildHistoryTab(context, provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTierCard(BuildContext context, LoyaltyProvider provider) {
    final member = provider.currentMember;
    if (member == null) return const SizedBox();

    final currentTier = provider.getTierByName(member.currentTier);
    final nextTier = provider.getTierByName('silver'); // Placeholder
    final progress =
        (provider.currentMember?.availablePoints ?? 0) * 10; // Placeholder

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(int.parse(
                '0xFF${currentTier?.color.replaceFirst('#', '') ?? 'FFFFFF'}')),
            Color(int.parse(
                    '0xFF${currentTier?.color.replaceFirst('#', '') ?? 'FFFFFF'}'))
                .withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier Name and Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Tier',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentTier?.name ?? 'Unknown',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              _getTierIcon(member.currentTier, 48),
            ],
          ),
          const SizedBox(height: 24),
          // Progress Bar
          if (nextTier != null) ...[
            Text(
              'Progress to ${nextTier.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${member.totalPoints} / ${nextTier.pointsRequired} points',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ] else ...[
            Text(
              'Congratulations! You\'re at the highest tier',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointsSummary(BuildContext context, LoyaltyProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              context,
              'Available Points',
              provider.availablePoints.toString(),
              Icons.stars,
              Colors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              context,
              'Total Earned',
              provider.totalPoints.toString(),
              Icons.trending_up,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              context,
              'Transactions',
              provider.currentMember?.totalTransactions.toString() ?? '0',
              Icons.receipt,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, LoyaltyProvider provider) {
    final member = provider.currentMember;
    if (member == null) return const SizedBox();

    final currentTier = provider.getTierByName(member.currentTier);
    final nextTier = provider.getTierByName('silver');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current Tier Benefits
        Text(
          'Current Tier Benefits',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (currentTier != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[600]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discount: ${currentTier.discountPercentage.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                ),
                const SizedBox(height: 12),
                ...currentTier.benefits.map(
                  (benefit) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            benefit,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        // Member Stats
        Text(
          'Member Statistics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _buildStatRow(
          context,
          'Total Spent',
          '₦${member.totalSpent.toStringAsFixed(2)}',
        ),
        _buildStatRow(
          context,
          'Transactions',
          member.totalTransactions.toString(),
        ),
        _buildStatRow(
          context,
          'Average Per Transaction',
          member.totalTransactions > 0
              ? '₦${(member.totalSpent / member.totalTransactions).toStringAsFixed(2)}'
              : '₦0.00',
        ),
        _buildStatRow(
          context,
          'Member Since',
          _formatDate(member.joinedDate),
        ),
        _buildStatRow(
          context,
          'Last Purchase',
          member.getDaysSinceLastTransaction() == 0
              ? 'Today'
              : '${member.getDaysSinceLastTransaction()} days ago',
        ),
        const SizedBox(height: 24),
        // Next Tier Info
        if (nextTier != null) ...[
          Text(
            'Next Tier: ${nextTier.name}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earn more points to upgrade tier',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Benefits: ${nextTier.discountPercentage.toStringAsFixed(0)}% discount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRewardsTab(BuildContext context, LoyaltyProvider provider) {
    final availablePoints = provider.availablePoints;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Available Points: $availablePoints',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
        ),
        const SizedBox(height: 24),
        _buildRewardOption(
          context,
          'Discount Voucher',
          'Redeem 100 points for 5% off',
          100,
          provider,
        ),
        const SizedBox(height: 12),
        _buildRewardOption(
          context,
          'Free Item',
          'Redeem 500 points for free item',
          500,
          provider,
        ),
        const SizedBox(height: 12),
        _buildRewardOption(
          context,
          'Premium Voucher',
          'Redeem 1000 points for 20% off',
          1000,
          provider,
        ),
        const SizedBox(height: 12),
        _buildRewardOption(
          context,
          'Exclusive Reward',
          'Redeem 2000 points for special gift',
          2000,
          provider,
        ),
      ],
    );
  }

  Widget _buildRewardOption(
    BuildContext context,
    String title,
    String description,
    int pointsCost,
    LoyaltyProvider provider,
  ) {
    final canRedeem = provider.availablePoints >= pointsCost;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canRedeem
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
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
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pointsCost pts',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canRedeem
                  ? () => _showRedeemConfirmation(
                        context,
                        provider,
                        title,
                        pointsCost,
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canRedeem ? Colors.green : Colors.grey[600],
                foregroundColor: Colors.white,
              ),
              child: Text(
                canRedeem
                    ? 'Redeem'
                    : 'Insufficient Points (${provider.availablePoints}/$pointsCost)',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, LoyaltyProvider provider) {
    if (provider.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No Transaction History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: provider.transactions.map((transaction) {
        final isEarning = transaction.isEarning();
        final color = isEarning ? Colors.green : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEarning ? Icons.add_circle : Icons.remove_circle,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.getFormattedType(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.description ?? 'No description',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isEarning ? '+' : '-'}${transaction.pointsAmount}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showRedeemConfirmation(
    BuildContext context,
    LoyaltyProvider provider,
    String rewardTitle,
    int pointsCost,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Redemption'),
        content: Text(
          'Redeem $pointsCost points for "$rewardTitle"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await provider.redeemRewards(
                memberId: provider.currentMember?.id ?? '',
                points: pointsCost,
                description: rewardTitle,
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Reward redeemed successfully!'
                          : 'Failed to redeem reward',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _getTierIcon(String tier, double size) {
    IconData icon;
    Color color;

    switch (tier.toLowerCase()) {
      case 'platinum':
        icon = Icons.diamond;
        color = const Color(0xFFE5E4E2);
        break;
      case 'gold':
        icon = Icons.star;
        color = const Color(0xFFFFD700);
        break;
      case 'silver':
        icon = Icons.star_half;
        color = const Color(0xFFC0C0C0);
        break;
      default:
        icon = Icons.circle;
        color = const Color(0xFFCD7F32);
    }

    return Icon(icon, size: size, color: color);
  }
}

