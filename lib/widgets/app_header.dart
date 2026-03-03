import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Text styles are now derived from Theme; specific AppTextStyles import removed

import '../providers/auth_provider.dart';
import 'profile_avatar.dart';
import '../providers/business_provider.dart';
import '../core/constants/routes.dart';
import '../services/snackbar_service.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  /// If `showBusinessSwitcher` is false the business name and popup are hidden.
  const AppHeader({super.key, this.showBusinessSwitcher = true});

  final bool showBusinessSwitcher;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bp = context.watch<BusinessProvider>();
    final user = auth.currentUser;
    final current = bp.currentBusiness;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          // Use ProfileAvatar to show photo when available with caching
          ProfileAvatar(
            photoUrl: user?.photoUrl,
            initials: user?.initials ?? 'U',
            radius: 28,
            backgroundColor: colorScheme.primary.withAlpha((0.12 * 255).toInt()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Welcome back', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                Text(
                  user?.fullName ?? 'User',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showBusinessSwitcher) ...[
                  const SizedBox(height: 2),
                  PopupMenuButton<String>(
                    tooltip: 'Select Business',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, 40),
                    onSelected: (id) async {
                      final authRead = context.read<AuthProvider>();
                      final selected = bp.userBusinesses.firstWhere((b) => b.id == id);
                      try {
                        if (authRead.currentUser != null) {
                          // Protect explicit selection and persist preference
                          bp.markUserSelection(authRead.currentUser!.id);
                          await bp.setCurrentBusinessAndSave(authRead.currentUser!.id, selected);
                          // Refresh auth so in-memory user doc reflects the new currentBusinessId
                          await authRead.refresh();
                        } else {
                          await bp.setCurrentBusiness(selected);
                        }

                        // Provide immediate user feedback
                        SnackBarService.showSnackBar(context: context, message: 'Switched to "${selected.name}"');
                      } catch (e) {
                        SnackBarService.showError(context, 'Failed to switch business: $e');
                      }
                    },
                    itemBuilder: (_) => bp.userBusinesses.map((b) => PopupMenuItem(value: b.id, child: Text(b.name))).toList(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_rounded, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              current?.name ?? 'No business selected',
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, Routes.notifications),
            icon: Icon(Icons.notifications_rounded, color: colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
