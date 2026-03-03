import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/text_styles.dart';
import '../core/theme/colors.dart';
import '../providers/connectivity_provider.dart';

class OfflineIndicator extends StatelessWidget {
  final bool showAlways;

  const OfflineIndicator({
    super.key,
    this.showAlways = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (connectivity.isConnected && !showAlways) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: connectivity.isConnected
                ? AppColors.warning
                : Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: connectivity.isConnected
                    ? AppColors.warning
                    : Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                connectivity.isConnected
                    ? Icons.cloud_off_rounded
                    : Icons.signal_cellular_nodata_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      connectivity.isConnected
                          ? 'Limited Connection'
                          : 'You\'re Offline',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connectivity.isConnected
                          ? 'Some features may be unavailable'
                          : 'Working in offline mode • Changes will sync when online',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withAlpha(0xE6),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onPrimary.withAlpha(0x40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'OFFLINE',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Offline banner for bottom sheet style display
class OfflineBottomBanner extends StatelessWidget {
  const OfflineBottomBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (connectivity.isConnected) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade600,
                Colors.grey.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'You\'re Currently Offline',
                style: AppTextStyles.heading4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your changes are being saved locally and will sync automatically when you\'re back online.',
                style: AppTextStyles.body2.copyWith(
                  color: Colors.white.withOpacity(0.85),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

