import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MarketerProvider>();
    provider.clearError();

    final marketer = await provider.loginMarketer(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (marketer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Unable to sign in'),
        ),
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.marketerDashboard,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketerProvider>();

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
                        'Marketer Portal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Manage registrations, follow up on pending businesses, and track commissions from one dedicated workspace.',
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
                        ],
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 32,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF06213B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your marketer access is separate from app admin access.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                              if (provider.errorMessage != null) ...[
                                const SizedBox(height: 18),
                                _InlineStatusCard(
                                  icon: Icons.error_outline_rounded,
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  borderColor: const Color(0xFFFECACA),
                                  textColor: const Color(0xFFB91C1C),
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
                                text: 'Sign In To Marketer Hub',
                                icon: Icons.login_rounded,
                                isLoading: provider.isLoading,
                                onPressed: provider.isLoading ? null : _submit,
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
                                    child: const Text('Forgot password?'),
                                  ),
                                ],
                              ),
                            ],
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
