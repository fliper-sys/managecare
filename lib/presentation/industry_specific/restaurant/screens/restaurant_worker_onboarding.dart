import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';

class RestaurantWorkerOnboarding extends StatefulWidget {
  final String workerName;
  final String workerId;

  const RestaurantWorkerOnboarding({
    super.key,
    required this.workerName,
    required this.workerId,
  });

  @override
  State<RestaurantWorkerOnboarding> createState() =>
      _RestaurantWorkerOnboardingState();
}

class _RestaurantWorkerOnboardingState
    extends State<RestaurantWorkerOnboarding> {
  int _currentStep = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Restaurant Worker Guide'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.red.shade700,
      ),
      body: Column(
        children: [
          // Progress Indicator
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 6,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
              ),
            ),
          ),

          // PageView with onboarding steps
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                _OnboardingStep1(),
                _OnboardingStep2(),
                _OnboardingStep3(),
                _OnboardingStep4(),
                _OnboardingStep5(),
                _OnboardingStep6(),
              ],
            ),
          ),

          // Navigation Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: CustomButton(
                      text: 'Back',
                      backgroundColor: AppColors.border,
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: _currentStep == 5 ? 'Start Working' : 'Next',
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade100,
              ),
              child: Icon(
                Icons.waving_hand,
                size: 60,
                color: Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to the Restaurant!',
            style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Thank you for joining our team! This guide will help you master the restaurant POS system and provide excellent service to our customers.',
            style: AppTextStyles.body1.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Key Responsibilities:\n• Take customer orders\n• Manage tables\n• Process payments\n• Ensure customer satisfaction',
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.shade100,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 60,
                color: Colors.orange.shade700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Taking Orders',
            style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _FeatureCard(
            icon: Icons.table_chart,
            title: 'Select a Table',
            description: 'Tap on an available table to begin taking an order.',
          ),
          const _FeatureCard(
            icon: Icons.menu,
            title: 'Browse Menu',
            description: 'Search and select items from the menu by category.',
          ),
          const _FeatureCard(
            icon: Icons.note_add,
            title: 'Add Special Requests',
            description:
                'Add special instructions or dietary requirements for each item.',
          ),
          const _FeatureCard(
            icon: Icons.check_circle,
            title: 'Confirm Order',
            description:
                'Review and confirm the order before sending to kitchen.',
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 60,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Order Receipts & Printing',
            style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _FeatureCard(
            icon: Icons.print,
            title: 'Kitchen Receipt',
            description:
                'Automatically prints to kitchen with all order details and special instructions.',
          ),
          const _FeatureCard(
            icon: Icons.receipt,
            title: 'Customer Receipt',
            description:
                'Shows item list, table number, and total for customer reference.',
          ),
          const _FeatureCard(
            icon: Icons.info_outline,
            title: 'Order Information',
            description:
                'Kitchen receipt includes prep time estimates for better coordination.',
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep4 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade100,
              ),
              child: Icon(
                Icons.assignment,
                size: 60,
                color: Colors.green.shade700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Managing Orders',
            style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _FeatureCard(
            icon: Icons.hourglass_bottom,
            title: 'Pending Orders',
            description:
                'View all active orders with their current status and preparation time.',
          ),
          const _FeatureCard(
            icon: Icons.notifications_active,
            title: 'Kitchen Updates',
            description: 'Get notified when orders are ready to be served.',
          ),
          const _FeatureCard(
            icon: Icons.delivery_dining,
            title: 'Serve Orders',
            description:
                'Update status when food is ready and delivered to the customer.',
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep5 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.shade100,
              ),
              child: Icon(
                Icons.payment,
                size: 60,
                color: Colors.purple.shade700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Checkout & Payment',
            style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _FeatureCard(
            icon: Icons.account_balance_wallet,
            title: 'Open Tab',
            description:
                'Customer\'s tab shows all ordered items and running total.',
          ),
          const _FeatureCard(
            icon: Icons.discount,
            title: 'Discounts & Promotions',
            description:
                'Apply discounts or promotions before finalizing the payment.',
          ),
          const _FeatureCard(
            icon: Icons.credit_card,
            title: 'Multiple Payment Methods',
            description:
                'Accept cash, card, or split payments based on customer preference.',
          ),
          const _FeatureCard(
            icon: Icons.receipt,
            title: 'Payment Receipt',
            description:
                'Customer receives itemized receipt after successful payment.',
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep6 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade100,
              ),
              child: Icon(
                Icons.tips_and_updates,
                size: 60,
                color: Colors.teal.shade700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Pro Tips for Success',
            style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _TipCard(
            number: '1',
            title: 'Be Attentive',
            description:
                'Check on tables regularly and respond to customer needs promptly.',
            color: Colors.teal,
          ),
          const _TipCard(
            number: '2',
            title: 'Accurate Orders',
            description:
                'Double-check order details before sending to kitchen to avoid mistakes.',
            color: Colors.teal,
          ),
          const _TipCard(
            number: '3',
            title: 'Clear Communication',
            description:
                'Use special instructions for customizations and dietary preferences.',
            color: Colors.teal,
          ),
          const _TipCard(
            number: '4',
            title: 'Fast Checkout',
            description: 'Process payments promptly to improve table turnover.',
            color: Colors.teal,
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final Color color;

  const _TipCard({
    required this.number,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                    title,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

