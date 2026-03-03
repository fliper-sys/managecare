import 'package:flutter/material.dart';
import 'dart:ui'; // Required for ImageFilter

import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Hidden tap-to-login shortcut
  int _logoTapCount = 0;
  DateTime? _firstLogoTapTime;

  // Animation Controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Hard-coded admin credentials
  static const String _adminEmail = 'MCadmin@mc.c';
  static const String _adminPassword = 'Xanther839@';

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    // Clear previous errors
    setState(() => _errorMessage = null);
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
       setState(() => _errorMessage = 'Please fill in all fields');
       return;
    }

    setState(() => _isLoading = true);
    
    // Simulate network delay for better UX feel
    await Future.delayed(const Duration(milliseconds: 800));

    // Simple credential validation
    if (email != _adminEmail || password != _adminPassword) {
      setState(() {
        _errorMessage = 'Invalid admin credentials';
        _isLoading = false;
      });
      return;
    }

    try {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/admin_dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Fallback color
      body: Stack(
        children: [
          // 1. Background Gradient & Shapes
          _buildBackground(),

          // 2. Main Login Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Admin Logo Floating above card
                      _buildLogo(),
                      const SizedBox(height: 30),

                      // Login Card
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            const Text(
                              'Admin Portal',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Secure Access Control',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Error Display
                            if (_errorMessage != null)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 20, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Inputs
                            CustomTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'admin@system.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.admin_panel_settings_outlined,
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
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Action Button
                            _isLoading
                                ? const Center(child: CustomLoadingIndicator())
                                : Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _handleAdminLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF8B5CF6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Authenticate',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Back Button
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Return to Main Login'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.9),
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

  Widget _buildBackground() {
    return Stack(
      children: [
        // Base Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E1065), // Deep Violet
                Color(0xFF4C1D95), // Violet
                Color(0xFF7C3AED), // Light Violet
              ],
            ),
          ),
        ),
        // Decorative Circles
        Positioned(
          top: -100,
          left: -100,
          child: _decorativeCircle(300, Colors.white.withOpacity(0.1)),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: _decorativeCircle(200, Colors.white.withOpacity(0.1)),
        ),
        // Blur Overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.1)),
        ),
      ],
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildLogo() {
    return GestureDetector(
      onTap: () => _handleLogoTap(),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.shield_moon_outlined,
          size: 48,
          color: Color(0xFF8B5CF6),
        ),
      ),
    );
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_firstLogoTapTime == null || now.difference(_firstLogoTapTime!) > const Duration(seconds: 5)) {
      _firstLogoTapTime = now;
      _logoTapCount = 1;
    } else {
      _logoTapCount += 1;
    }

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _firstLogoTapTime = null;
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/admin_dashboard');
      }
    }
  }
}