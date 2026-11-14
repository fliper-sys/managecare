import '../../data/models/business_model.dart';
import '../../providers/business_provider.dart';
import 'business_session.dart';

/// The only file that knows about both the provider and the session state.
/// It reads getters that already exist on [BusinessProvider]; nothing in the
/// provider changes.
BusinessRef businessRefFrom(BusinessModel m) => BusinessRef(
      id: m.id,
      name: m.name,
      type: m.businessType,
      planActive: m.isSubscriptionActive,
      planEnd: m.subscriptionEndDate,
      logoUrl: m.logoUrl ?? m.photoUrl,
    );

BusinessSessionState sessionStateFrom(BusinessProvider p) {
  final list = p.userBusinesses.map(businessRefFrom).toList();
  return BusinessSessionState.derive(
    businesses: list,
    currentId: p.currentBusiness?.id,
    isLoading: p.isLoading,
    isSwitching: p.isSwitchingBusiness,
    pendingId: p.pendingBusinessId,
    usingCache: p.isUsingCachedData,
    errorMessage: p.errorMessage,
  );
}
