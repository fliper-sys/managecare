import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      _emailController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      _emailSent = success;
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Failed to send email'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
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
            top: -110,
            right: -70,
            size: 240,
            color: const Color(0xFF27D2A2).withOpacity(0.10),
          ),
          _buildAccentOrb(
            bottom: -110,
            left: -70,
            size: 220,
            color: const Color(0xFFF3B35C).withOpacity(0.10),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: _buildContentCard(isDark),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF10223F);
    final bodyColor =
        isDark ? Colors.white.withOpacity(0.72) : const Color(0xFF61708A);
    final cardColor =
        isDark ? const Color(0xFF0F1D36).withOpacity(0.96) : Colors.white;
    final supportSurface =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF8FAFC);
    final supportBorder =
        isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.22),
            blurRadius: 36,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: supportSurface,
                  foregroundColor: titleColor,
                  side: BorderSide(color: supportBorder),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _emailSent ? 'Email sent' : 'Account recovery',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.18),
                    AppColors.primary.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                _emailSent
                    ? Icons.mark_email_read_outlined
                    : Icons.lock_reset_rounded,
                size: 46,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _emailSent ? 'Check Your Email' : 'Reset Password',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _emailSent
                ? 'We sent a reset link to your email address. Open your inbox and follow the steps to create a new password.'
                : 'Enter your email address and we will send you a secure link to reset your password.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(
              color: bodyColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          if (!_emailSent) ...[
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
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CustomLoadingIndicator())
                : CustomButton(
                    text: 'Send Reset Link',
                    onPressed: _handleResetPassword,
                    icon: Icons.send_outlined,
                  ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: supportSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: supportBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Didn\'t receive the email? Check your spam folder or resend the reset link.',
                      style: AppTextStyles.body2.copyWith(
                        color: bodyColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Back To Sign In',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.login_rounded,
            ),
            const SizedBox(height: 14),
            CustomButton(
              text: 'Resend Email',
              onPressed: () => setState(() => _emailSent = false),
              type: ButtonType.outlined,
              icon: Icons.refresh_rounded,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Remember your password? ',
                style: AppTextStyles.body2.copyWith(color: bodyColor),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
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
              colors: [color, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

