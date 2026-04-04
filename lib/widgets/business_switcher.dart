import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/business_provider.dart';
import '../providers/reports_provider.dart';
import '../presentation/industry_specific/barber_shop/providers/barber_shop_provider.dart';
import '../presentation/industry_specific/wholesale/providers/wholesale_provider.dart';
import '../providers/retail_provider.dart';
import '../providers/pharmacy_provider.dart';
import '../providers/drink_provider.dart';
import '../presentation/industry_specific/restaurant/providers/restaurant_provider.dart';
import '../presentation/industry_specific/salon/providers/salon_provider.dart';
import '../providers/auto_provider.dart';
import '../providers/agri_provider.dart';

import '../core/utils/context_extensions.dart';
import '../providers/hotel_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/inventory_alerts_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/gym_provider.dart';
import '../providers/workers_provider.dart';
import '../providers/loyalty_provider.dart';
import '../presentation/industry_specific/realestate/providers/real_estate_provider.dart';
import '../services/local_user_storage.dart';
import '../services/snackbar_service.dart';
import '../services/startup_notifications.dart';
import '../core/constants/business_types.dart';
import 'async_button.dart';
// BusinessModel import not required here

/// Reusable business switcher widget.
/// Shows current business name and a popup menu to switch or add.
class BusinessSwitcher extends StatefulWidget {
  const BusinessSwitcher({super.key});

  @override
  State<BusinessSwitcher> createState() => _BusinessSwitcherState();
}

class _BusinessSwitcherState extends State<BusinessSwitcher> {
  bool _suppressConfirmation = false;
  String? _loadedForUserId;
  String? _loadedBusinessesForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Defer potentially-notifying work until after the first frame so
    // providers don't call notifyListeners() while widgets are being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLoadSuppressFlag();
      _maybeLoadUserBusinesses();
    });
  }

  Future<void> _maybeLoadSuppressFlag() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;
    if (_loadedForUserId == userId) return;
    try {
      final storage = await LocalUserStorage.create();
      final flag = storage.getSuppressBusinessSwitchConfirmationForUser(userId);
      if (mounted) {
        setState(() {
          _suppressConfirmation = flag;
          _loadedForUserId = userId;
        });
      }
    } catch (e) {
      // ignore errors and default to false
    }
  }

  Future<void> _maybeLoadUserBusinesses() async {
    final auth = context.read<AuthProvider>();
    final bp = context.read<BusinessProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    if (_loadedBusinessesForUserId == user.id) return;

    try {
      // Load businesses for this user. Prefer the user's currentBusinessId as preferred.
      await bp.loadUserBusinesses(user.id,
          preferredBusinessId: user.preferredBusinessId ?? user.currentBusinessId,
          userBusinessIds: user.businessIds);
      _loadedBusinessesForUserId = user.id;
    } catch (e) {
      // best-effort; ignore errors
      debugPrint('[BusinessSwitcher] Failed to load businesses for user ${user.id}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BusinessProvider>();
    final auth = context.watch<AuthProvider>();
    final businesses = bp.userBusinesses;
    final current = bp.currentBusiness;
    final isSwitching = bp.isSwitchingBusiness;

    // If the auth user changed and we haven't loaded businesses for them yet, do it now.
    if (auth.currentUser?.id != null && _loadedBusinessesForUserId != auth.currentUser?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadUserBusinesses());
    }

    return Row(
      children: [
        Icon(Icons.storefront,
            size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        GestureDetector(
          onLongPress: () async {
            final userId = auth.currentUser?.id;
            if (userId == null) return;
            try {
              final storage = await LocalUserStorage.create();
              final enabled = storage.getEdgeLoggingForUser(userId);
              final result = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(enabled ? 'Disable diagnostic logs?' : 'Enable diagnostic logs?'),
                  content: Text(enabled
                      ? 'Edge diagnostic logs are currently enabled for your account. Disable them?'
                      : 'Enable edge diagnostic logs for business loading (useful when restarting the app to capture verbose logs)?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Toggle')),
                  ],
                ),
              );

              if (result == true) {
                final newVal = !enabled;
                await storage.setEdgeLoggingForUser(userId, newVal);
                try {
                  await bp.setEdgeLoggingForUser(userId, newVal);
                } catch (_) {}
                if (mounted) {
                  // Use the global SnackBarService to avoid using a potentially
                  // deactivated BuildContext for SnackBar lifecycle.
                  SnackBarService.showSnackBar(
                      message: newVal ? 'Edge logs enabled. Restart the app to capture logs.' : 'Edge logs disabled.',
                      context: context,
                      duration: const Duration(seconds: 2));
                }
              }
            } catch (e) {
              debugPrint('[BusinessSwitcher] Failed toggling edge log for user $userId: $e');
            }
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              isSwitching
                  ? 'Switching...'
                  : (current?.name ?? 'No business selected').length > 10
                      ? '${(current?.name ?? 'No business selected').substring(0, 10)}...'
                      : current?.name ?? 'No business selected',
              style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        PopupMenuButton<Object?>(
          enabled: !isSwitching,
          icon: isSwitching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_down, size: 20),
          onSelected: (value) async {
            final id = value as String?;
            if (id == '_add_business') {
              final chosen = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Select Business Type'),
                  children: BusinessTypes.all.map((bt) {
                    return SimpleDialogOption(
                      onPressed: () => Navigator.of(ctx).pop(bt.id),
                      child: Row(
                        children: [
                          Icon(bt.icon, color: bt.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bt.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(bt.description, style: Theme.of(ctx).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
              if (chosen != null) {
                Navigator.pushNamed(context, '/business-details',
                    arguments: {'businessType': chosen});
              }
              return;
            }

            final selected = businesses.firstWhere((b) => b.id == id);

            // If user has suppressed confirmation, skip dialog
            final currentUserId = auth.currentUser?.id;
            if (_suppressConfirmation && currentUserId != null) {
              await _performSwitch(auth, bp, selected);
              return;
            }

            // Show confirmation dialog before switching businesses with a "Don't ask again" checkbox
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                bool dontAskAgain = false;
                return StatefulBuilder(
                  builder: (ctx2, setState2) => AlertDialog(
                    title: const Text('Switch Business?'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You are about to switch from "${current?.name ?? 'No business'}" to "${selected.name}".'),
                        const SizedBox(height: 8),
                        const Text(
                          'Switching will change the app\'s data context and may cause unsaved work to be lost. Continue?',
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: dontAskAgain,
                          onChanged: (v) => setState2(() => dontAskAgain = v ?? false),
                          title: const Text("Don't ask again"),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx2).pop(false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.of(ctx2).pop(dontAskAgain ? true : true), child: const Text('Switch')),
                    ],
                  ),
                );
              },
            );

            if (confirmed != true) return;

            // If user chose don't ask again, persist preference
            // Note: we re-check currentUserId as it may have changed
            if (currentUserId != null) {
              // Retrieve the flag chosen in dialog by re-opening a dialog state? We can't get the local variable here.
              // Instead, we will open the dialog and capture dontAskAgain via the StatefulBuilder return value.
              // Workaround: change dialog to return a map { 'confirmed': true, 'dontAskAgain': bool }
            }

            // To capture "Don't ask again" properly, showDialog must return both values. We'll implement below.

            final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) {
              bool dontAskAgain = false;
              return StatefulBuilder(builder: (ctx2, setState2) {
                return AlertDialog(
                  title: const Text('Switch Business?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You are about to switch from "${current?.name ?? 'No business'}" to "${selected.name}".'),
                      const SizedBox(height: 8),
                      const Text('Switching will change the app\'s data context and may cause unsaved work to be lost. Continue?'),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: dontAskAgain,
                        onChanged: (v) => setState2(() => dontAskAgain = v ?? false),
                        title: const Text("Don't ask again"),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx2).pop({'confirmed': false, 'dontAskAgain': dontAskAgain}), child: const Text('Cancel')),
                    AsyncButton(onPressed: () async => Navigator.of(ctx2).pop({'confirmed': true, 'dontAskAgain': dontAskAgain}), child: const Text('Switch')),
                  ],
                );
              });
            });

            if (result == null || result['confirmed'] != true) return;
            final dontAskAgain = result['dontAskAgain'] == true;

            if (dontAskAgain && currentUserId != null) {
              try {
                final storage = await LocalUserStorage.create();
                await storage.setSuppressBusinessSwitchConfirmationForUser(currentUserId, true);
                if (mounted) setState(() => _suppressConfirmation = true);
              } catch (e) {
                // ignore failures to persist preference
              }
            }

            await _performSwitch(auth, bp, selected);
          },
          itemBuilder: (_) {
            // Ensure we present unique businesses in stable order
            final seen = <String>{};
            final display = <dynamic>[];
            for (final b in businesses) {
              if (seen.add(b.id)) display.add(b);
            }

            final items = display
                .map<PopupMenuEntry<Object?>>((b) => PopupMenuItem<Object?>(value: b.id, child: Text(b.name)))
                .toList();
            items.add(const PopupMenuDivider());
            items.add(const PopupMenuItem<Object?>(
                value: '_add_business', child: ListTile(leading: Icon(Icons.add), title: Text('Add Business'))));
            return items;
          },
        ),
      ],
    );
  }

  Future<void> _performSwitch(AuthProvider auth, BusinessProvider bp, dynamic selected) async {
    final switchStart = DateTime.now();
    try {
      if (bp.isSwitchingBusiness) return;
      if (bp.currentBusiness?.id == selected.id) return;

      final currentUserId = auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not available for business switch');
      }

      // 1) Persist selection in auth (important)
      final tAuthStart = DateTime.now();
      final oldAuthBiz = auth.currentUser?.currentBusinessId;
      debugPrint('[BusinessSwitcher] Pre-switch Auth.currentBusinessId: $oldAuthBiz; selected.id: ${selected.id}');
      final authSwitchOk = await auth.switchBusiness(selected.id);
      if (!authSwitchOk) {
        throw Exception('Unable to switch auth business context');
      }
      final tAuthEnd = DateTime.now();
      debugPrint('[BusinessSwitcher] auth.switchBusiness: ${tAuthEnd.difference(tAuthStart).inMilliseconds}ms');
      debugPrint('[BusinessSwitcher] Post-switch Auth.currentBusinessId: ${auth.currentUser?.currentBusinessId}');

      // 2) Update business provider with a single coordinated switch path.
      final tLocalStart = DateTime.now();
      bp.markUserSelection(currentUserId);
      final resolvedBusiness = await bp.switchToBusinessAndSync(
        userId: currentUserId,
        selectedBusiness: selected,
      );
      final tLocalEnd = DateTime.now();
      debugPrint('[BusinessSwitcher] bp.switchToBusinessAndSync: ${tLocalEnd.difference(tLocalStart).inMilliseconds}ms');

      // 3) Show immediate feedback to the user (fast)
      if (mounted) {
        SnackBarService.showSnackBar(message: 'Switched to "${resolvedBusiness.name}"', context: context, duration: const Duration(seconds: 2));
      }

      // 4) Kick off provider updates in parallel (fire-and-forget) to avoid blocking the UI
      Future<void> safeCall(FutureOr<void> Function() cb, String name) async {
        final start = DateTime.now();
        try {
          await Future.sync(cb);
          final dur = DateTime.now().difference(start).inMilliseconds;
          debugPrint('[BusinessSwitcher] $name finished (${dur}ms)');
        } catch (e) {
          debugPrint('[BusinessSwitcher] $name failed: $e');
        }
      }

      final futures = <Future>[];

      // Resolve the authoritative business id after auth/local updates
      final resolvedBid = resolvedBusiness.id;
      debugPrint('[BusinessSwitcher] Resolved business id for background updates: $resolvedBid (selected=${selected.id}, bp.current=${bp.currentBusiness?.id}, auth.current=${auth.currentUser?.currentBusinessId})');

      // Lightweight subscriptions (non-blocking) - use resolved id
      futures.add(safeCall(() {
        final reports = Provider.of<ReportsProvider>(context, listen: false);
        reports.subscribeToSalesReports(businessId: resolvedBid);
        reports.subscribeToFinancialReports(businessId: resolvedBid);
        reports.subscribeToInventoryReports(businessId: resolvedBid);
      }, 'Reports subscriptions'));

      // Industry providers - do not await these sequentially; run in parallel (use resolved id)
      futures.add(safeCall(() => Provider.of<RetailProvider>(context, listen: false).setBusinessId(resolvedBid), 'RetailProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<PharmacyProvider>(context, listen: false).setBusinessId(resolvedBid), 'PharmacyProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<DrinkProvider>(context, listen: false).setBusinessId(resolvedBid), 'DrinkProvider.setBusinessId'));
      futures.add(safeCall(() async {
        final restaurant = Provider.of<RestaurantProvider>(context, listen: false);
        restaurant.setBusinessId(resolvedBid);
        await Future.wait([
          restaurant.initializeMenu(businessId: resolvedBid),
          restaurant.initializeOrders(businessId: resolvedBid),
          restaurant.initializeTables(businessId: resolvedBid),
          restaurant.initializeReservations(businessId: resolvedBid),
          restaurant.initializeServers(businessId: resolvedBid),
          restaurant.initializeWasteRecords(businessId: resolvedBid),
        ]);
      }, 'RestaurantProvider.initializeAll'));
      futures.add(safeCall(() => Provider.of<SalonProvider>(context, listen: false).setBusinessId(resolvedBid), 'SalonProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<BarberShopProvider>(context, listen: false).setBusinessId(resolvedBid), 'BarberShopProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<AutoProvider>(context, listen: false).setBusinessId(resolvedBid), 'AutoProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<AgriProvider>(context, listen: false).setBusinessId(resolvedBid), 'AgriProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<HotelProvider>(context, listen: false).setBusinessId(resolvedBid), 'HotelProvider.setBusinessId'));

      // Wholesale init (best-effort)
      futures.add(safeCall(() {
        final wholesale = Provider.of<WholesaleProvider>(context, listen: false);
        wholesale.initializeWithBusinessId(resolvedBid);
      }, 'Wholesale.initialize'));

      // Customer, Inventory Alerts, Analytics, Gym - run in background
      futures.add(safeCall(() => Provider.of<CustomerProvider>(context, listen: false).setBusinessId(resolvedBid), 'CustomerProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<InventoryAlertsProvider>(context, listen: false).setBusinessId(resolvedBid), 'InventoryAlerts.setBusinessId'));
      futures.add(safeCall(() => Provider.of<AnalyticsProvider>(context, listen: false).setBusinessId(resolvedBid), 'AnalyticsProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<GymProvider>(context, listen: false).setBusinessId(resolvedBid), 'GymProvider.setBusinessId'));

      // Barber: set business id then kick off loads in background
      futures.add(safeCall(() {
        final barber = Provider.of<BarberShopProvider>(context, listen: false);
        barber.setBusinessId(resolvedBid);
        barber.loadAppointments();
        barber.loadServices();
        barber.loadBarbers();
        barber.loadSales();
      }, 'BarberProvider.loadAll'));

      // Workers and Loyalty may be heavier - run them in background too
      futures.add(safeCall(() => Provider.of<WorkersProvider>(context, listen: false).setBusinessId(resolvedBid), 'WorkersProvider.setBusinessId'));
      futures.add(safeCall(() => Provider.of<LoyaltyProvider>(context, listen: false).initialize(resolvedBid), 'LoyaltyProvider.initialize'));

      // Real estate best-effort loads
      futures.add(safeCall(() {
        final realEstate = context.tryRead<RealEstateProvider>();
        if (realEstate != null) {
          realEstate.loadProperties();
          realEstate.loadTenants();
          realEstate.loadBookings();
          realEstate.loadRentPayments();
        }
      }, 'RealEstateProvider.loads'));

      // Also refresh auth in background (non-blocking)
      auth.refresh().then((_) => debugPrint('[BusinessSwitcher] auth.refresh completed')).catchError((e) => debugPrint('[BusinessSwitcher] auth.refresh failed: $e'));

      // Run startup notifications in background
      StartupNotifications.run(context).then((_) => debugPrint('[BusinessSwitcher] StartupNotifications finished')).catchError((e) => debugPrint('[BusinessSwitcher] StartupNotifications failed: $e'));

      // Log background completion - we don't await here to keep switch fast for user
      Future.wait(futures).then((_) {
        debugPrint('[BusinessSwitcher] Background provider updates completed in ${DateTime.now().difference(switchStart).inMilliseconds}ms');
      }).catchError((e) {
        debugPrint('[BusinessSwitcher] Background provider updates encountered an error: $e');
      });
    } catch (e) {
      if (mounted) {
        SnackBarService.showError(context, 'Failed to switch business: $e');
      }
    } finally {
      debugPrint('[BusinessSwitcher] Switch main path took ${DateTime.now().difference(switchStart).inMilliseconds}ms');
    }
  }
}

