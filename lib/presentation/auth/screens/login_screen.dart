import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/lottie_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _workerIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isWorkerLogin = false;
  bool _didPrefillEmail = false;
  int _appIconTaps = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didPrefillEmail) return;
      final lastEmail = context.read<AuthProvider>().getLastLoggedInEmail();
      if (lastEmail != null && lastEmail.trim().isNotEmpty) {
        _emailController.text = lastEmail.trim();
      }
      _didPrefillEmail = true;
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _workerIdController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    bool success = false;

    if (_isWorkerLogin) {
      success = await runWithLottieErrorHandling<bool>(
            context,
            () => authProvider.loginAsWorker(
              workerId: _workerIdController.text.trim(),
              password: _passwordController.text,
            ),
            errorTitle: 'Worker Login Error',
          ) ??
          false;
    } else {
      success = await runWithLottieErrorHandling<bool>(
            context,
            () => authProvider.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
            errorTitle: 'Login Error',
          ) ??
          false;
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      final user = authProvider.currentUser!;
      if (user.isOwner) {
        Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
      } else {
        final businessProvider = context.read<BusinessProvider>();
        final businessId = user.businessId;

        if (businessId.isNotEmpty) {
          try {
            await businessProvider.loadBusinessById(businessId);
          } catch (_) {}

          var industryRoute =
              businessProvider.getIndustryRouteForCurrentBusiness();
          if (industryRoute == null || industryRoute.isEmpty) {
            industryRoute =
                businessProvider.getIndustryRouteForType(user.businessType);
          }

          if (industryRoute != null && industryRoute.isNotEmpty) {
            Navigator.of(context).pushReplacementNamed(industryRoute);
          } else {
            Navigator.of(context).pushReplacementNamed(Routes.workerDashboard);
          }
        } else {
          await businessProvider.ensureBusinessForWorker(
            user.id,
            workerEmail: user.email,
          );

          var industryRoute =
              businessProvider.getIndustryRouteForCurrentBusiness();
          if (industryRoute == null || industryRoute.isEmpty) {
            industryRoute =
                businessProvider.getIndustryRouteForType(user.businessType);
          }

          if (industryRoute != null && industryRoute.isNotEmpty) {
            Navigator.of(context).pushReplacementNamed(industryRoute);
          } else {
            Navigator.of(context).pushReplacementNamed(Routes.workerDashboard);
          }
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          return Stack(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF081126),
                      Color(0xFF0D2445),
                      Color(0xFF13386A),
                    ],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              _buildAccentOrb(
                top: -120,
                right: -90,
                size: 260,
                color: const Color(0xFF27D2A2).withOpacity(0.12),
              ),
              _buildAccentOrb(
                top: 150,
                left: -70,
                size: 220,
                color: const Color(0xFFF3B35C).withOpacity(0.10),
              ),
              _buildAccentOrb(
                bottom: -120,
                right: 80,
                size: 240,
                color: Colors.white.withOpacity(0.06),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 40 : 20,
                      vertical: isWide ? 28 : 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Form(
                        key: _formKey,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: isWide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 11,
                                        child: _buildHeroPanel(isWide: true),
                                      ),
                                      const SizedBox(width: 28),
                                      Expanded(
                                        flex: 10,
                                        child: _buildAuthCard(isWide: true),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildHeroPanel(isWide: false),
                                      const SizedBox(height: 24),
                                      _buildAuthCard(isWide: false),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroPanel({required bool isWide}) {
    return Padding(
      padding: EdgeInsets.only(right: isWide ? 8 : 0),
      child: Column(
        crossAxisAlignment:
            isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _appIconTaps++);
              if (_appIconTaps >= 7) {
                _appIconTaps = 0;
                Navigator.of(context).pushNamed(Routes.adminLogin);
              } else if (_appIconTaps > 1 && _appIconTaps < 7) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Taps: $_appIconTaps/7'),
                    duration: const Duration(milliseconds: 500),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.black54,
                    margin: const EdgeInsets.all(20),
                  ),
                );
              }
            },
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x33FFFFFF),
                      Color(0x18FFFFFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/app_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.business_center_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              _isWorkerLogin
                  ? 'Shift-ready access for staff'
                  : 'Operations hub for business owners',
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFFE7F1FF),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isWorkerLogin
                ? 'Step into your shift with clarity.'
                : 'Run the day without losing the details.',
            textAlign: isWide ? TextAlign.left : TextAlign.center,
            style: AppTextStyles.heading1.copyWith(
              color: Colors.white,
              fontSize: isWide ? 44 : 34,
              height: 1.06,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: isWide ? 460 : 560,
            child: Text(
              _isWorkerLogin
                  ? 'Clock into bookings, payments, and customer flow with a faster staff sign-in experience.'
                  : 'Track bookings, rooms, staff, payments, and reports from one focused workspace built for busy businesses.',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: AppTextStyles.body1.copyWith(
                color: Colors.white.withOpacity(0.80),
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: const [
              _HeroStat(
                icon: Icons.calendar_month_rounded,
                title: 'Bookings',
                subtitle: 'Stay ahead of every appointment',
              ),
              _HeroStat(
                icon: Icons.notifications_active_rounded,
                title: 'Alerts',
                subtitle: 'Receive timely operational reminders',
              ),
              _HeroStat(
                icon: Icons.receipt_long_rounded,
                title: 'Sales',
                subtitle: 'Keep checkout and records moving',
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today feels easier when your team can see what matters next.',
                  style: AppTextStyles.heading5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Use owner access for the full command center or worker access for focused shift operations.',
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.white.withOpacity(0.76),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard({required bool isWide}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 30 : 24,
        vertical: isWide ? 30 : 26,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isWorkerLogin ? 'Worker Sign In' : 'Owner Sign In',
            style: AppTextStyles.heading3.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF10223F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isWorkerLogin
                ? 'Use your worker ID and password to access shift tools.'
                : 'Use your business email and password to continue.',
            style: AppTextStyles.body2.copyWith(
              color: const Color(0xFF61708A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _buildToggleOption(
                  title: 'Owner',
                  isSelected: !_isWorkerLogin,
                  onTap: () => setState(() {
                    _isWorkerLogin = false;
                    _clearFields();
                  }),
                ),
                _buildToggleOption(
                  title: 'Worker',
                  isSelected: _isWorkerLogin,
                  onTap: () => setState(() {
                    _isWorkerLogin = true;
                    _clearFields();
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isWorkerLogin
                ? CustomTextField(
                    key: const ValueKey('workerId'),
                    controller: _workerIdController,
                    label: 'Worker ID',
                    hint: 'Enter your staff ID',
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'ID required' : null,
                  )
                : CustomTextField(
                    key: const ValueKey('email'),
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'name@business.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return 'Email required';
                      if (!v!.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter your secure password',
            obscureText: !_isPasswordVisible,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade600,
              ),
              onPressed: () => setState(
                () => _isPasswordVisible = !_isPasswordVisible,
              ),
            ),
            validator: (v) =>
                (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
          ),
          if (!_isWorkerLogin) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.forgotPassword),
                child: Text(
                  'Forgot Password?',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isWorkerLogin
                        ? 'Staff access is scoped to the active business workspace.'
                        : 'Owner access unlocks full settings, reporting, and operations control.',
                    style: AppTextStyles.body2.copyWith(
                      color: const Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CustomLoadingIndicator())
              : SizedBox(
                  height: 54,
                  child: CustomButton(
                    text: _isWorkerLogin ? 'Start Shift' : 'Enter Dashboard',
                    onPressed: _handleLogin,
                  ),
                ),
          if (!_isWorkerLogin)
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: AppTextStyles.body2.copyWith(
                      color: const Color(0xFF61708A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed(Routes.register),
                    child: Text(
                      'Create one',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.marketerLogin),
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('Marketers login'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF486284),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccentOrb({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(
              color:
                  isSelected ? AppColors.primary : const Color(0xFF64748B),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _clearFields() {
    _workerIdController.clear();
    _emailController.clear();
    _passwordController.clear();
    if (!_isWorkerLogin) {
      final lastEmail = context.read<AuthProvider>().getLastLoggedInEmail();
      if (lastEmail != null && lastEmail.trim().isNotEmpty) {
        _emailController.text = lastEmail.trim();
      }
    }
    _formKey.currentState?.reset();
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HeroStat({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.body1.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.74),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
