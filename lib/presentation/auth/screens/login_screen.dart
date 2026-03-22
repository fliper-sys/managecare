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
  int _appIconTaps = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

  // --- LOGIC SECTION (UNTOUCHED) ---
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
          await businessProvider.ensureBusinessForWorker(user.id,
              workerEmail: user.email);

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
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Login failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  // --- END LOGIC SECTION ---

  @override
  Widget build(BuildContext context) {
    // Get screen height to handle small screens better

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
            ),
          ),

          // 2. Decorative Background Circle (Top Right)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color.fromARGB(255, 24, 49, 95).withOpacity(0.1),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Animations wrapper
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              // App Icon Logic with Hidden Admin Access
                              GestureDetector(
                                onTap: () {
                                  setState(() => _appIconTaps++);
                                  if (_appIconTaps >= 7) {
                                    _appIconTaps = 0;
                                    Navigator.of(context)
                                          .pushNamed(Routes.adminLogin);
                                  } else if (_appIconTaps > 1 &&
                                      _appIconTaps < 7) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Taps: $_appIconTaps/7'),
                                        duration:
                                            const Duration(milliseconds: 500),
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
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                  color: const Color.fromARGB(124, 90, 105, 189),
                                  borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/app_icon.png',
                                      height: 60,
                                      width: 60,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.business_center_rounded,
                                        size: 40,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Text Header
                              Text(
                                'Welcome Back',
                                style: AppTextStyles.heading1.copyWith(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Login to manage your business efficiently',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body1.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),

                      // Floating Login Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Custom Segmented Toggle
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
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
                            const SizedBox(height: 24),

                            // Fields
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isWorkerLogin
                                  ? CustomTextField(
                                      key: const ValueKey('workerId'),
                                      controller: _workerIdController,
                                      label: 'Worker ID',
                                      hint: 'Enter your ID',
                                      prefixIcon: Icons.badge_outlined,
                                      validator: (v) => v?.isEmpty == true
                                          ? 'ID required'
                                          : null,
                                    )
                                  : CustomTextField(
                                      key: const ValueKey('email'),
                                      controller: _emailController,
                                      label: 'Email Address',
                                      hint: 'name@business.com',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.email_outlined,
                                      validator: (v) {
                                        if (v?.isEmpty == true)
                                          return 'Email required';
                                        if (!v!.contains('@'))
                                          return 'Invalid email';
                                        return null;
                                      },
                                    ),
                            ),
                            const SizedBox(height: 16),

                            CustomTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: '••••••••',
                              obscureText: !_isPasswordVisible,
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(() =>
                                    _isPasswordVisible = !_isPasswordVisible),
                              ),
                              validator: (v) => (v?.length ?? 0) < 6
                                  ? 'Min 6 characters'
                                  : null,
                            ),

                            // Forgot Password (Owner only)
                            if (!_isWorkerLogin) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(Routes.forgotPassword),
                                  child: Text(
                                    'Forgot Password?',
                                    style: AppTextStyles.body2.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Submit Button
                            _isLoading
                                ? const Center(child: CustomLoadingIndicator())
                                : SizedBox(
                                    height: 52,
                                    child: CustomButton(
                                      text: 'Sign In',
                                      onPressed: _handleLogin,
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      // Sign Up Footer
                      if (!_isWorkerLogin)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: AppTextStyles.body1.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context)
                                    .pushNamed(Routes.register),
                                child: Text(
                                  'Sign Up',
                                  style: AppTextStyles.body1.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Marketers login link (visible from main login)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pushNamed(Routes.adminLogin),
                            child: Text(
                              'Marketers login',
                              style: AppTextStyles.body2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for the toggle
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
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
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
    _formKey.currentState?.reset();
  }
}