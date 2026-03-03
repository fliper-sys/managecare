import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../providers/business_provider.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Builder(builder: (context) {
              final businessProvider = Provider.of<BusinessProvider?>(context, listen: false);
              final industryRoute = businessProvider?.getIndustryRouteForCurrentBusiness();
              return _buildActionButton(
                context,
                'Open Dashboard',
                Icons.dashboard,
                () {
                  if (industryRoute != null) {
                    Navigator.pushNamed(context, industryRoute);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Industry dashboard not available')));
                  }
                },
              );
            }),
            _buildActionButton(
              context,
              'New Sale',
              Icons.add_shopping_cart,
              () => Navigator.pushNamed(context, Routes.sales),
            ),
            _buildActionButton(
              context,
              'Check Stock',
              Icons.inventory,
              () => Navigator.pushNamed(context, Routes.inventory),
            ),
            _buildActionButton(
              context,
              'Add Customer',
              Icons.person_add,
              () => Navigator.pushNamed(context, Routes.customersAdd),
            ),
            _buildActionButton(
              context,
              'View Reports',
              Icons.bar_chart,
              () => Navigator.pushNamed(context, Routes.reports),
            ),
            _buildActionButton(
              context,
              'Printer Settings',
              Icons.print,
              () => Navigator.pushNamed(context, Routes.printerSettings),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

