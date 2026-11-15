import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/business_provider.dart';
import 'ui_v2.dart';

/// Shows [v2] only for a business of type [type] that is on v2, otherwise
/// [legacy]. Routes that several business types share (sales history, for
/// one) use this so a retail rollout never changes another type's screens.
///
/// [v2] and [legacy] are builders, so the screen not chosen is never built.
class UiV2Switch extends StatelessWidget {
  const UiV2Switch({super.key, required this.type, required this.v2, required this.legacy});

  final String type;
  final WidgetBuilder v2;
  final WidgetBuilder legacy;

  /// The decision on its own, for tests: the business type must match and v2
  /// must be enabled for that type.
  static bool useV2(String? businessType, String type, {String? buildFlag, Set<String>? overrideSet}) {
    final current = (businessType ?? '').trim().toLowerCase();
    return current == type && UiV2.enabledFor(type, buildFlag: buildFlag, overrideSet: overrideSet);
  }

  @override
  Widget build(BuildContext context) {
    final current = context.select<BusinessProvider, String?>((p) => p.currentBusiness?.businessType);
    return useV2(current, type) ? v2(context) : legacy(context);
  }
}
