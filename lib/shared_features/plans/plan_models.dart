import 'package:flutter/foundation.dart';

import '../../services/subscription_service.dart';

/// One purchasable plan: a tier at one billing length.
@immutable
class PlanChoice {
  const PlanChoice({
    required this.planId,
    required this.tierId,
    required this.durationLabel,
    required this.days,
    required this.price,
    required this.features,
  });

  final String planId;
  final String tierId;
  final String durationLabel;
  final int days;
  final double price;
  final List<String> features;

  double get perMonth => days <= 0 ? price : price / (days / 30);
}

/// A tier with every billing length it is sold in, shortest first.
@immutable
class TierGroup {
  const TierGroup({required this.tierId, required this.name, required this.choices});

  final String tierId;
  final String name;
  final List<PlanChoice> choices;

  List<String> get features => choices.first.features;

  /// Saving of the longest plan against paying the shortest repeatedly, in
  /// percent. Zero when there is one length or no saving.
  int get bestSavingPercent {
    if (choices.length < 2) return 0;
    final base = choices.first.perMonth;
    final best = choices.map((c) => c.perMonth).reduce((a, b) => a < b ? a : b);
    if (base <= 0 || best >= base) return 0;
    return ((base - best) / base * 100).round();
  }
}

String tierDisplayName(String tierId) {
  final m = RegExp(r'^tier(\d+)$').firstMatch(tierId);
  return m == null ? tierId : 'Tier ${m.group(1)}';
}

/// Groups flat choices into tiers, ordered by tier id then length.
List<TierGroup> groupTiers(List<PlanChoice> all) {
  final byTier = <String, List<PlanChoice>>{};
  for (final c in all) {
    byTier.putIfAbsent(c.tierId, () => []).add(c);
  }
  final ids = byTier.keys.toList()..sort();
  return [
    for (final id in ids)
      TierGroup(
        tierId: id,
        name: tierDisplayName(id),
        choices: (byTier[id]!..sort((a, b) => a.days.compareTo(b.days))),
      ),
  ];
}

/// Plans a business type can buy, from the existing catalogue.
List<PlanChoice> planChoicesFor(String? businessType) => [
      for (final p in SubscriptionService.getPlansForBusinessType(businessType))
        PlanChoice(
          planId: p.id,
          tierId: p.tierId,
          durationLabel: p.billingLabel,
          days: p.durationInDays,
          price: p.price,
          features: p.features,
        ),
    ];
