import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/routes.dart';
import '../../data/repositories/admin_repository.dart';
import '../../providers/marketer_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class MarketerLoginScreen extends StatefulWidget {
  const MarketerLoginScreen({super.key});

  @override
  State<MarketerLoginScreen> createState() => _MarketerLoginScreenState();
}

class _MarketerLoginScreenState extends State<MarketerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    context.read<MarketerProvider>().clearError();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isInternalWorkerLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MarketerProvider>();
    provider.clearError();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final marketer = await provider.loginMarketer(email, password);

    if (!mounted) return;

    if (marketer != null) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.marketerDashboard,
        (route) => false,
      );
      return;
    }

    // Don't surface the marketer-specific rejection reason (e.g. "Marketer
    // not found") - it would leak which of the two identity systems the
    // credentials were checked against before falling through.
    provider.clearError();
    await _tryInternalWorkerLogin(email, password);
  }

  Future<void> _tryInternalWorkerLogin(String email, String password) async {
    setState(() => _isInternalWorkerLoading = true);
    try {
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      if (authResponse.session == null) {
        throw Exception('No session');
      }
      final worker = await AdminRepository().fetchMyWorkerProfile();
      if (worker['id'] == null) {
        throw Exception('Not an internal worker');
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.internalWorkerDashboard,
        (route) => false,
      );
    } catch (_) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials')),
      );
    } finally {
      if (mounted) setState(() => _isInternalWorkerLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketerProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF0E1A2F).withOpacity(0.96) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF06213B);
    final bodyColor = isDark
        ? Colors.white.withOpacity(0.74)
        : Colors.grey.shade600;
    final supportSurface = isDark
        ? Colors.white.withOpacity(0.06)
        : const Color(0xFFF0FDFA);
    final supportBorder = isDark
        ? Colors.white.withOpacity(0.10)
        : const Color(0xFFCCFBF1);
    final errorBackground = isDark
        ? const Color(0xFF3A1218)
        : const Color(0xFFFEF2F2);
    final errorBorder = isDark
        ? const Color(0xFF7F1D1D)
        : const Color(0xFFFECACA);
    final errorText = isDark
        ? const Color(0xFFFECACA)
        : const Color(0xFFB91C1C);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF06213B),
                  Color(0xFF0F4C81),
                  Color(0xFF11998E),
                ],
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -50,
            child: _buildGlow(
              size: 220,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -40,
            child: _buildGlow(
              size: 280,
              color: const Color(0xFF6EE7B7).withOpacity(0.12),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Marketer & Worker Portal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Manage marketer work or sign in as an internal ManageCare worker from one dedicated workspace.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _FeatureChip(
                            icon: Icons.person_add_alt_1_rounded,
                            label: 'New leads',
                          ),
                          _FeatureChip(
                            icon: Icons.storefront_rounded,
                            label: 'Business onboarding',
                          ),
                          _FeatureChip(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Commission tracking',
                          ),
                          _FeatureChip(
                            icon: Icons.engineering_rounded,
                            label: 'Worker tasks',
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.white.withOpacity(0.55),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.30 : 0.16,
                              ),
                              blurRadius: 32,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: theme.copyWith(
                            inputDecorationTheme:
                                theme.inputDecorationTheme.copyWith(
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : const Color(0xFFF8FAFC),
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Use marketer or internal worker credentials. App admin access stays separate.',
                                  style: TextStyle(
                                    color: bodyColor,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: supportSurface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: supportBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F766E)
                                              .withOpacity(0.14),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.security_rounded,
                                          color: Color(0xFF14B8A6),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Internal workers created by super admins can sign in here with their email and temporary password.',
                                          style: TextStyle(
                                            color: bodyColor,
                                            height: 1.45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (provider.errorMessage != null) ...[
                                  const SizedBox(height: 18),
                                  _InlineStatusCard(
                                    icon: Icons.error_outline_rounded,
                                    backgroundColor: errorBackground,
                                    borderColor: errorBorder,
                                    textColor: errorText,
                                    message: provider.errorMessage!,
                                  ),
                                ],
                                const SizedBox(height: 20),
                                CustomTextField(
                                  controller: _emailController,
                                  label: 'Marketer email',
                                  hint: 'Enter your email',
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.alternate_email_rounded,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter your marketer email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  hint: 'Enter password',
                                  obscureText: _obscurePassword,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.68)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                CustomButton(
                                  text: 'Sign In',
                                  icon: Icons.login_rounded,
                                  isLoading: provider.isLoading ||
                                      _isInternalWorkerLoading,
                                  onPressed:
                                      (provider.isLoading ||
                                              _isInternalWorkerLoading)
                                          ? null
                                          : _submit,
                                  backgroundColor: const Color(0xFF0F766E),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(
                                          Routes.marketerForgotPassword,
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: isDark
                                            ? const Color(0xFF5EEAD4)
                                            : const Color(0xFF0F766E),
                                      ),
                                      child:
                                          const Text('Forgot password?'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(Routes.login);
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back to main login'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
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

  Widget _buildGlow({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStatusCard extends StatelessWidget {
  const _InlineStatusCard({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.message,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
