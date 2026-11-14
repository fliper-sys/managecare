import 'package:flutter/foundation.dart';

import '../../../design/components/plan_summary_card.dart';

/// A row in the home's attention list (low stock, due supplier delivery).
@immutable
class AttentionRow {
  const AttentionRow({required this.id, required this.title, required this.subtitle});

  final String id;
  final String title;
  final String subtitle;
}

/// A label with a count, for the "Needs a look" card.
@immutable
class CountRow {
  const CountRow({required this.label, required this.count});

  final String label;
  final int count;
}

/// Everything the Retail home needs, already computed. A connector (phase 3b)
/// fills this from the existing providers; the view itself reads no state.
@immutable
class RetailHomeData {
  const RetailHomeData({
    required this.businessName,
    required this.greetingName,
    required this.salesToday,
    required this.deltaPercent,
    required this.salesCount,
    required this.spark,
    required this.plan,
    required this.lowStock,
    required this.pending,
  });

  final String businessName;
  final String greetingName;
  final double salesToday;

  /// Change against yesterday, in percent. Negative when sales are down.
  final double deltaPercent;
  final int salesCount;
  final List<double> spark;
  final PlanSummary plan;
  final List<AttentionRow> lowStock;
  final List<CountRow> pending;
}
