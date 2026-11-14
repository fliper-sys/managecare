import 'package:flutter/foundation.dart';

import '../business_profiles/business_profiles.dart';

/// Switch for the v2 screens, checked where the router builds a business's
/// home and sales screens.
///
/// A business is on v2 only when it is listed in the build flag (or in the
/// runtime override set) AND it has a migrated profile. So `UI_V2=all` never
/// turns on a business that has not been migrated.
///
///   flutter run --dart-define=UI_V2=retail
///   flutter run --dart-define=UI_V2=all
class UiV2 {
  const UiV2._();

  static const String _buildFlag = String.fromEnvironment('UI_V2');

  /// Runtime override, for a hidden settings switch on pilot devices.
  static final ValueNotifier<Set<String>> overrides =
      ValueNotifier<Set<String>>(<String>{});

  static bool enabledFor(
    String businessType, {
    String? buildFlag,
    Set<String>? overrideSet,
  }) {
    final id = businessType.trim().toLowerCase();
    if (id.isEmpty) return false;
    if (BusinessProfiles.forType(id) == null) return false;

    final flags = (buildFlag ?? _buildFlag)
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final o = (overrideSet ?? overrides.value).map((e) => e.toLowerCase()).toSet();

    return flags.contains('all') || flags.contains(id) || o.contains(id);
  }
}
