import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/access_control.dart';
import '../../../widgets/profile_avatar.dart';
import 'currency_management_screen.dart';
import 'notification_preferences_screen.dart';
import 'backup_and_restore_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final user = authProvider.currentUser;
    final business = businessProvider.currentBusiness;
    final businessType = business?.businessType.toLowerCase() ?? '';
    final isFuelStation = businessType.contains('gas') ||
        businessType.contains('petroleum') ||
        businessType.contains('petrol') ||
        businessType.contains('filling');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, scheme.secondary, 0.55)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withOpacity(isDark ? 0.22 : 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    photoUrl: user?.photoUrl,
                    initials: user?.initials ?? 'U',
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'User',
                          style: AppTextStyles.heading4.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        if (business != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              business.name,
                              style: AppTextStyles.body2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.profile);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Business Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    'Business',
                    style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.72),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    children: [
                      _SettingsItem(
                        icon: Icons.business_outlined,
                        title: 'Business Information',
                        subtitle: 'Name, address, contact details',
                        onTap: () {
                          Navigator.pushNamed(context, Routes.businessSettings);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Subscription',
                        subtitle: business != null
                            ? '${business.subscriptionTier.toUpperCase()} Plan'
                            : 'Manage your plan',
                        trailing: business != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  business.subscriptionTier.toUpperCase(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pushNamed(context, Routes.subscription);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.receipt_outlined,
                        title: 'Tax Settings',
                        subtitle: 'Configure tax rates',
                        onTap: () {
                          Navigator.pushNamed(context, Routes.taxSettings);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.print_outlined,
                        title: 'Printer Settings',
                        subtitle: 'Receipt printer configuration',
                        onTap: () {
                          Navigator.pushNamed(context, Routes.printerSettings);
                        },
                      ),
                      if (isFuelStation) ...[
                        const Divider(height: 1),
                        _SettingsItem(
                          icon: Icons.local_gas_station_outlined,
                          title: 'Pump Configuration',
                          subtitle: 'Add pumps and assign fuel products',
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              businessType.contains('petroleum')
                                  ? Routes.petroleumPumpConfiguration
                                  : Routes.gasPumpConfiguration,
                            );
                          },
                        ),
                      ],
                      // Show Dunning Status only to admins or business owners
                      if (AccessControl.canAccessDunning(context)) ...[
                        const Divider(height: 1),
                        _SettingsItem(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Dunning Status',
                          subtitle: 'Subscription recovery / dunning runs',
                          onTap: () {
                            Navigator.pushNamed(context, Routes.adminDunning);
                          },
                        ),
                      ],
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.people_outlined,
                        title: 'Workers Management',
                        subtitle: 'Add and manage team members',
                        onTap: () {
                          Navigator.pushNamed(context, Routes.workers);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Preferences Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferences',
                    style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.72),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    children: [
                      _SettingsItem(
                        icon: themeProvider.isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: 'Dark Mode',
                        subtitle: 'Toggle dark theme',
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                        onTap: () {
                          themeProvider.toggleTheme();
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Manage notification preferences',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationPreferencesScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.language_outlined,
                        title: 'Language',
                        subtitle: 'English (US)',
                        onTap: () {
                          _showLanguageSelector(context);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.attach_money_outlined,
                        title: 'Currency',
                        subtitle: business?.currency ?? 'NGN',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CurrencyManagementScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Data & Privacy Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data & Privacy',
                    style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.72),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    children: [
                      _SettingsItem(
                        icon: Icons.backup_outlined,
                        title: 'Backup & Restore',
                        subtitle: 'Manage your data backups',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BackupAndRestoreScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.file_download_outlined,
                        title: 'Export Sales History',
                        subtitle: 'Download your sales data',
                        onTap: () {
                          Navigator.pushNamed(
                              context, Routes.exportSalesHistory);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'Read our privacy policy',
                        onTap: () {
                          _showPrivacyPolicy(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support',
                    style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.72),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    children: [
                      _SettingsItem(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        subtitle: 'FAQs and guides',
                        onTap: () {
                          _showHelpCenter(context);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.chat_bubble_outline,
                        title: 'Contact Support',
                        subtitle: 'Get help from our team',
                        onTap: () {
                          _showContactSupport(context);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.star_outline,
                        title: 'Rate Us',
                        subtitle: 'Share your feedback',
                        onTap: () {
                          _showRatingDialog(context);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        subtitle: 'Version 1.0.51',
                        onTap: () {
                          _showAboutDialog(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showLogoutDialog(context, authProvider);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.login,
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption('English (US)', 'en', context),
            _LanguageOption('French', 'fr', context),
            _LanguageOption('Spanish', 'es', context),
            _LanguageOption('Portuguese', 'pt', context),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: AppTextStyles.heading3,
              ),
              SizedBox(height: 16),
              Text(
                'We are committed to protecting your privacy. This privacy policy explains how we collect, use, and safeguard your information.\n\n'
                '1. Information Collection\n'
                'We collect information necessary to provide our services.\n\n'
                '2. Data Protection\n'
                'Your data is encrypted and securely stored.\n\n'
                '3. Data Sharing\n'
                'We do not share your data with third parties without consent.\n\n'
                'For more information, visit our website.',
                style: AppTextStyles.body2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Center'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpItem('Getting Started', 'Learn the basics of Manage Care'),
              _HelpItem('Sales Management', 'How to process and manage sales'),
              _HelpItem(
                  'Inventory Management', 'Track and manage your inventory'),
              _HelpItem('Customer Management', 'Manage your customer database'),
              _HelpItem('Reports', 'Generate and view business reports'),
              _HelpItem('Settings', 'Configure app preferences'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Get in touch with us:'),
            SizedBox(height: 16),
            _ContactOption('📧 Email', 'mc@globalthrivealliance.com'),
            _ContactOption('📱 Phone', '+234 8063124936'),
            _ContactOption('💬 WhatsApp', '+234 8063124936'),
            _ContactOption('🕐 Hours', 'Mon-Fri: 9AM - 6PM'),
            _ContactOption('Made with ❤️ ', ' by LoveBari'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Manage Care'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you rate our app?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Thank you for rating ${index + 1} stars!'),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.star_outline),
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Manage Care'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Care',
              style: AppTextStyles.heading3,
            ),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            Text('Build: 1'),
            SizedBox(height: 16),
            Text(
              'A comprehensive business management app supporting 9+ industries including pharmacy, retail, agriculture, auto repair, salon, hotel, restaurant, bar, and real estate.',
              style: AppTextStyles.body2,
            ),
            SizedBox(height: 16),
            Text(
              '© 2025 Manage Care. All rights reserved.',
              style: AppTextStyles.body2Secondary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withOpacity(isDark ? 0.08 : 0.02),
          theme.cardColor,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: scheme.primary, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.68),
            ),
      ),
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: scheme.onSurface.withOpacity(0.45),
          ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

// Helper widget for language option
class _LanguageOption extends StatelessWidget {
  final String label;
  final String code;
  final BuildContext parentContext;

  const _LanguageOption(this.label, this.code, this.parentContext);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text('Language changed to $label')),
        );
        Navigator.pop(context);
      },
    );
  }
}

// Helper widget for currency option
// Commented out as currently unused - can be used for currency selection UI in future
// ignore: unused_element
class _CurrencyOption extends StatelessWidget {
  final String label;
  final String code;
  final BuildContext parentContext;

  const _CurrencyOption(this.label, this.code, this.parentContext);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text('Currency changed to $code')),
        );
        Navigator.pop(context);
      },
    );
  }
}

// Helper widget for help item
class _HelpItem extends StatelessWidget {
  final String title;
  final String description;

  const _HelpItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.68),
              ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// Helper widget for contact option
class _ContactOption extends StatelessWidget {
  final String label;
  final String value;

  const _ContactOption(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.68),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $value'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

