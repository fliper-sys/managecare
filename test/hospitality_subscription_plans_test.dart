import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/subscription_service.dart';

void main() {
  test('hospitality businesses expose every plan tier', () {
    final plans = SubscriptionService.getPlansForBusinessType('hospitality');

    expect(
      plans.map((plan) => plan.tierId).toSet(),
      {'tier1', 'tier2', 'tier3', 'unlimited'},
    );
  });

  test('hotel and hospitality use the same plan family', () {
    final hotelPlans = SubscriptionService.getPlansForBusinessType('hotel');
    final hospitalityPlans =
        SubscriptionService.getPlansForBusinessType('hospitality business');

    expect(
      hospitalityPlans.map((plan) => plan.id).toList(),
      hotelPlans.map((plan) => plan.id).toList(),
    );
  });
}
