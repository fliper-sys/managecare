import 'package:flutter/widgets.dart';

/// Minimal localization hook used as a placeholder for real i18n.
/// Replace this with `intl` or generated ARB-based localization when ready.
class AppLocalizations {
  static const Map<String, String> _en = {
    'checkout': 'Checkout',
    'cart_empty': 'Cart is empty',
    'total': 'Total',
    'confirm_pay': 'Confirm & Pay',
    'checkout_success': 'Checkout successful',
    'syncing_inventory': 'Syncing inventory...',
    'inventory_synced': 'Inventory synced',
    'sync_inventory': 'Sync Inventory',
    'open_pos': 'Open POS',
    'catalog': 'Catalog',
    'suppliers': 'Suppliers',
    'top_selling': 'Top Selling Items',
    'recent_orders': 'Recent Orders',
    'quick_actions': 'Quick Actions',
    'store_status': 'Store Status',
  };

  static String tr(BuildContext context, String key) {
    // Basic hook: always returns English map entry. Integrate with real locale later.
    return _en[key] ?? key;
  }
}

