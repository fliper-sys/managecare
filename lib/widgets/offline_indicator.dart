import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/text_styles.dart';
import '../core/theme/colors.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_provider.dart';

class OfflineIndicator extends StatelessWidget {
  final bool showAlways;

  const OfflineIndicator({
    super.key,
    this.showAlways = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, SyncProvider>(
      builder: (context, connectivity, sync, _) {
        if (connectivity.isConnected && !showAlways && sync.pendingItems == 0) {
          return const SizedBox.shrink();
        }

        final hasPendingItems = sync.pendingItems > 0;
        final isSyncing = sync.isSyncing;
        final isOnline = connectivity.isConnected;

        return GestureDetector(
          // Tapping "Sync Now" when online with pending items triggers sync
          onTap: (isOnline && hasPendingItems && !isSyncing)
              ? () => context.read<SyncProvider>().syncNow()
              : null,
          child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: connectivity.isConnected
                ? (hasPendingItems ? AppColors.warning : AppColors.success)
                : Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: connectivity.isConnected
                    ? (hasPendingItems ? AppColors.warning : AppColors.success)
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
                    ? (isSyncing ? Icons.sync : hasPendingItems ? Icons.cloud_upload : Icons.cloud_done)
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
                          ? (isSyncing ? 'Syncing...' : hasPendingItems ? 'Pending Sync' : 'Online')
                          : 'You\'re Offline',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline
                          ? (isSyncing
                              ? 'Uploading ${sync.pendingItems} pending sale${sync.pendingItems == 1 ? '' : 's'}...'
                              : hasPendingItems
                                  ? '${sync.pendingItems} sale${sync.pendingItems == 1 ? '' : 's'} waiting to upload — tap to sync now'
                                  : 'All changes synced')
                          : 'Sales saved locally • Will upload automatically when back online',
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
                child: isSyncing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        isOnline
                            ? (hasPendingItems ? 'SYNC NOW' : 'ONLINE')
                            : 'OFFLINE',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                      ),
              ),
            ],
          ),
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

