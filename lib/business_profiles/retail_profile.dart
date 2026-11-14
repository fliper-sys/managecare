import 'package:flutter/material.dart';

import 'business_profile.dart';

/// Wave 1 (pilot): Retail Store.
const BusinessProfile retailProfile = BusinessProfile(
  id: 'retail',
  label: 'Retail Store',
  accent: Color(0xFF2563EB),
  planFamily: PlanFamily.standard,
  template: ScreenTemplate.catalogueCart,
  terms: Terms(
    sale: 'Sale',
    newSale: 'New sale',
    item: 'Product',
    items: 'Products',
    customer: 'Customer',
    completeCta: 'Complete sale',
    doneTitle: 'Sale recorded',
    walkIn: 'Walk-in',
  ),
  kpiLabel: 'Today’s sales',
  kpiDeltaLabel: 'vs yesterday',
  quickActions: [
    QuickAction(id: 'quick_sale', label: 'Quick sale', icon: Icons.bolt, target: QuickActionTarget.newSale),
    QuickAction(id: 'add_product', label: 'Add product', icon: Icons.inventory_2_outlined, target: QuickActionTarget.addItem),
    QuickAction(id: 'stock_count', label: 'Stock count', icon: Icons.checklist, target: QuickActionTarget.stockCount),
    QuickAction(id: 'reports', label: 'Reports', icon: Icons.bar_chart, target: QuickActionTarget.reports),
  ],
  workTabLabel: 'Stock',
  workTitle: 'Stock and orders',
  workFilters: ['All', 'Today', 'Needs attention'],
  capabilities: {
    Capability.wholesalePricing,
    Capability.multiStore,
    Capability.suppliers,
    Capability.promotions,
    Capability.barcodeScan,
    Capability.offlineSales,
    Capability.invoicing,
  },
  wave: 1,
);
