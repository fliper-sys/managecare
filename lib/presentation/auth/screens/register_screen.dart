import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';

enum PasswordStrength { weak, fair, good, strong }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _passwordController.addListener(_updatePasswordStrength);
    _confirmPasswordController.addListener(_refreshPasswordFeedback);
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

    _animationController.forward();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    PasswordStrength strength = PasswordStrength.weak;

    if (password.length >= 8) {
      bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
      bool hasLowercase = password.contains(RegExp(r'[a-z]'));
      bool hasNumbers = password.contains(RegExp(r'[0-9]'));
      bool hasSpecialChars =
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      int strengthCount = 0;
      if (hasUppercase) strengthCount++;
      if (hasLowercase) strengthCount++;
      if (hasNumbers) strengthCount++;
      if (hasSpecialChars) strengthCount++;

      if (strengthCount == 1) {
        strength = PasswordStrength.fair;
      } else if (strengthCount == 2) {
        strength = PasswordStrength.good;
      } else if (strengthCount >= 3) {
        strength = PasswordStrength.strong;
      }
    }

    setState(() => _passwordStrength = strength);
  }

  void _refreshPasswordFeedback() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      referralEmail: _referralController.text.trim().isEmpty ? null : _referralController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed(Routes.businessSelection);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Registration failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                right: -80,
                size: 260,
                color: const Color(0xFF27D2A2).withOpacity(0.12),
              ),
              _buildAccentOrb(
                top: 170,
                left: -80,
                size: 240,
                color: const Color(0xFFF3B35C).withOpacity(0.10),
              ),
              _buildAccentOrb(
                bottom: -110,
                right: 90,
                size: 260,
                color: Colors.white.withOpacity(0.05),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 40 : 20,
                      vertical: isWide ? 28 : 18,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
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
                                        child: _buildAuthCard(
                                          isWide: true,
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildHeroPanel(isWide: false),
                                      const SizedBox(height: 24),
                                      _buildAuthCard(
                                        isWide: false,
                                        isDark: isDark,
                                      ),
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
        children: [
          Align(
            alignment: isWide ? Alignment.centerLeft : Alignment.center,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.08),
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                ),
              ),
            ),
          ),
          SizedBox(height: isWide ? 40 : 24),
          Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [Color(0x33FFFFFF), Color(0x16FFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              'Owner account setup',
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFFE7F1FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Build the business workspace you actually want to use.',
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
            width: isWide ? 470 : 560,
            child: Text(
              'Create your account, choose your business category, and move into sales, inventory, staff, and reports from one clean setup flow.',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: AppTextStyles.body1.copyWith(
                color: Colors.white.withOpacity(0.78),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroStat(
                icon: Icons.storefront_rounded,
                title: 'Any business type',
                subtitle: 'Retail, hospitality, pharmacy, beauty, and more.',
              ),
              _buildHeroStat(
                icon: Icons.shield_outlined,
                title: 'Secure onboarding',
                subtitle: 'Strong-password guidance and verified owner access.',
              ),
              _buildHeroStat(
                icon: Icons.sync_alt_rounded,
                title: 'Ready to scale',
                subtitle: 'Add more businesses later without starting over.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard({required bool isWide, required bool isDark}) {
    final theme = Theme.of(context);
    final cardColor =
        isDark ? const Color(0xFF0F1D36).withOpacity(0.96) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF10223F);
    final bodyColor =
        isDark ? Colors.white.withOpacity(0.72) : const Color(0xFF61708A);
    final supportSurface =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF8FAFC);
    final supportBorder =
        isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFE2E8F0);
    final passwordMatches =
        _passwordController.text == _confirmPasswordController.text;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 30 : 24,
        vertical: isWide ? 30 : 26,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.32 : 0.22),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Account',
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use your owner details to set up a new workspace. You can add businesses and choose plans after this step.',
              style: AppTextStyles.body2.copyWith(
                color: bodyColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            CustomTextField(
              controller: _fullNameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              prefixIcon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                if (value.length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'name@business.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter your phone number',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _referralController,
              label: 'Referral Email (optional)',
              hint: 'Enter referral email if any',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.link_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null;
                }
                if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Create a strong password',
              obscureText: !_isPasswordVisible,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: supportSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: supportBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _passwordStrength.index / 3,
                              minHeight: 7,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getStrengthColor(),
                              ),
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.10)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getStrengthLabel(),
                          style: AppTextStyles.body2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _getStrengthColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Use uppercase, lowercase, numbers, and a special character for a stronger password.',
                      style: AppTextStyles.caption.copyWith(
                        color: bodyColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              obscureText: !_isConfirmPasswordVisible,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            if (_confirmPasswordController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: passwordMatches
                      ? Colors.green.withOpacity(isDark ? 0.18 : 0.10)
                      : AppColors.error.withOpacity(isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: passwordMatches
                        ? Colors.green.withOpacity(0.28)
                        : AppColors.error.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      passwordMatches
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: passwordMatches ? Colors.green : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        passwordMatches
                            ? 'Passwords match and are ready to use.'
                            : 'Passwords do not match yet.',
                        style: AppTextStyles.body2.copyWith(
                          color:
                              passwordMatches ? Colors.green : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: supportSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: supportBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (value) {
                      setState(() => _acceptedTerms = value ?? false);
                    },
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, right: 8),
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: AppTextStyles.body2.copyWith(
                            color: bodyColor,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CustomLoadingIndicator())
                : CustomButton(
                    text: 'Create Account',
                    onPressed: _handleRegister,
                    icon: Icons.arrow_forward_rounded,
                  ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: AppTextStyles.body2.copyWith(color: bodyColor),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Sign In',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStat({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: 170,
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
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.72),
              height: 1.45,
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

  Color _getStrengthColor() {
    switch (_passwordStrength) {
      case PasswordStrength.weak:
        return AppColors.error;
      case PasswordStrength.fair:
        return Colors.orange;
      case PasswordStrength.good:
        return Colors.blue;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  String _getStrengthLabel() {
    switch (_passwordStrength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }
}

