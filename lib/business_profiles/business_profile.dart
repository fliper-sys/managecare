import 'package:flutter/material.dart';

/// Which screen shell a business uses (see the Restructuring Blueprint).
enum ScreenTemplate { catalogueCart, bookingSchedule, roomsTables, specialised }

/// Plan families, matching subscription_service.dart.
enum PlanFamily {
  standard,
  pharmacy,
  kitchen,
  lounge,
  hospitality,
  fuel,
  administrative,
}

/// Things a business can do that shared screens switch on. Shared code reads
/// these instead of comparing business-type text.
enum Capability {
  wholesalePricing,
  multiStore,
  suppliers,
  promotions,
  barcodeScan,
  offlineSales,
  invoicing,
  expiryTracking,
}

/// Where a quick action leads. Shared screens map each target to a route.
enum QuickActionTarget { newSale, addItem, stockCount, reports, workFeed }

@immutable
class QuickAction {
  const QuickAction({required this.id, required this.label, required this.icon, required this.target});

  final String id;
  final String label;
  final IconData icon;
  final QuickActionTarget target;
}

/// The words a business uses for the same ideas.
@immutable
class Terms {
  const Terms({
    required this.sale,
    required this.newSale,
    required this.item,
    required this.items,
    required this.customer,
    required this.completeCta,
    required this.doneTitle,
    required this.walkIn,
  });

  final String sale;
  final String newSale;
  final String item;
  final String items;
  final String customer;
  final String completeCta;
  final String doneTitle;
  final String walkIn;
}

/// Everything that differs between businesses and is only data. One instance
/// per business type; shared screens read it.
@immutable
class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.label,
    required this.accent,
    required this.planFamily,
    required this.template,
    required this.terms,
    required this.kpiLabel,
    required this.kpiDeltaLabel,
    required this.quickActions,
    required this.workTabLabel,
    required this.workTitle,
    required this.workFilters,
    required this.capabilities,
    required this.wave,
  });

  final String id;
  final String label;

  /// The business accent. Profiles are one of the places raw colours are
  /// allowed; screens must take the accent from here.
  final Color accent;
  final PlanFamily planFamily;
  final ScreenTemplate template;
  final Terms terms;

  /// Hero figure label, for example "Today's sales".
  final String kpiLabel;

  /// Comparison label, for example "vs yesterday".
  final String kpiDeltaLabel;
  final List<QuickAction> quickActions;

  /// Bottom-tab label and screen title of the work feed.
  final String workTabLabel;
  final String workTitle;

  /// Three filter labels: all, soon, needs attention.
  final List<String> workFilters;
  final Set<Capability> capabilities;

  /// Rollout wave from the blueprint (1 is the pilot).
  final int wave;

  bool can(Capability c) => capabilities.contains(c);
}
