import 'business_profile.dart';
import 'retail_profile.dart';

export 'business_profile.dart';
export 'retail_profile.dart';

/// Registry of migrated business types. A type is added here when its wave
/// passes its gate; until then [forType] returns null and the old screens are
/// used.
class BusinessProfiles {
  const BusinessProfiles._();

  static const Map<String, BusinessProfile> _migrated = {
    'retail': retailProfile,
  };

  static BusinessProfile? forType(String businessType) =>
      _migrated[businessType.trim().toLowerCase()];

  static Iterable<BusinessProfile> get all => _migrated.values;
}
