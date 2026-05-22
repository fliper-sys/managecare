import 'package:flutter/material.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';

class WorkerOnboardingScreen extends StatefulWidget {
  final String workerName;
  final String workerId;

  const WorkerOnboardingScreen({
    super.key,
    required this.workerName,
    required this.workerId,
  });

  @override
  State<WorkerOnboardingScreen> createState() => _WorkerOnboardingScreenState();
}

class _WorkerOnboardingScreenState extends State<WorkerOnboardingScreen> {
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
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Complete onboarding
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.drinkPos,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Worker Onboarding'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.brown,
      ),
      body: Column(
        children: [
          // Progress Indicator
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 5,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.brown.shade600),
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
                    text: _currentStep == 4 ? 'Get Started' : 'Next',
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
                color: Colors.brown.shade100,
              ),
              child: const Icon(
                Icons.waving_hand,
                size: 60,
                color: Colors.brown,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to the Bar!',
            style: AppTextStyles.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your role as a bartender is crucial to our operation. This quick guide will help you understand how to use the Bar POS system efficiently.',
            style: AppTextStyles.body1.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Key Responsibilities:\n• Handle customer orders\n• Process payments\n• Manage inventory',
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.blue.shade900,
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
              child: const Icon(
                Icons.local_bar,
                size: 60,
                color: Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Understanding the POS System',
            style: AppTextStyles.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _FeatureCard(
            icon: Icons.search,
            title: 'Search Drinks',
            description: 'Use the search bar to quickly find drinks by name.',
          ),
          const _FeatureCard(
            icon: Icons.shopping_cart,
            title: 'Add to Cart',
            description: 'Tap any drink to add it to the customer\'s order.',
          ),
          const _FeatureCard(
            icon: Icons.edit,
            title: 'Modify Cart',
            description: 'Adjust quantities or remove items before checkout.',
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
                color: Colors.green.shade100,
              ),
              child: const Icon(
                Icons.shopping_bag,
                size: 60,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'The Order Flow',
            style: AppTextStyles.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _OrderFlowStep(
            number: 1,
            title: 'Select Items',
            description: 'Browse menu and add drinks to cart',
          ),
          const _OrderFlowStep(
            number: 2,
            title: 'Review Order',
            description: 'Check quantities and prices before proceeding',
          ),
          const _OrderFlowStep(
            number: 3,
            title: 'Process Payment',
            description: 'Choose payment method and complete transaction',
          ),
          const _OrderFlowStep(
            number: 4,
            title: 'Print Receipt',
            description: 'System automatically prints order receipt',
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
                color: Colors.purple.shade100,
              ),
              child: const Icon(
                Icons.payment,
                size: 60,
                color: Colors.purple,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Payment Methods',
            style: AppTextStyles.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _PaymentMethodCard(
            icon: Icons.money,
            title: 'Cash',
            description: 'For direct cash payments',
          ),
          const _PaymentMethodCard(
            icon: Icons.credit_card,
            title: 'Card',
            description: 'Accept debit/credit card payments',
          ),
          const _PaymentMethodCard(
            icon: Icons.account_balance_wallet,
            title: 'Digital Wallet',
            description: 'Mobile money and digital payments',
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
                color: Colors.teal.shade100,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: Colors.teal,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Quick Tips & Best Practices',
            style: AppTextStyles.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _TipCard(
            icon: Icons.tips_and_updates,
            title: 'Always Verify Orders',
            description:
                'Double-check drink names and quantities before finalizing.',
          ),
          const _TipCard(
            icon: Icons.speed,
            title: 'Use Search Feature',
            description: 'It\'s faster than scrolling through the full menu.',
          ),
          const _TipCard(
            icon: Icons.storage,
            title: 'Monitor Stock',
            description: 'Alert management if a popular drink is running low.',
          ),
          const _TipCard(
            icon: Icons.security,
            title: 'Secure Your Session',
            description: 'Log out when leaving the terminal to prevent errors.',
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.subtitle1),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
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

class _OrderFlowStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const _OrderFlowStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade600,
            ),
            alignment: Alignment.center,
            child: Text(
              number.toString(),
              style: AppTextStyles.subtitle1.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.subtitle1),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
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

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.subtitle1),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
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

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.subtitle2.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.amber.shade800,
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

