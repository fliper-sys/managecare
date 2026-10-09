import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/subscription_service.dart';

void main() {
  test('pharmacy plans expose the requested prices by tier and duration', () {
    final plans = SubscriptionService.getPlansForBusinessType('pharmacy');

    expect(plans, hasLength(9));
    expect(
      plans.map((plan) => plan.price),
      [30885, 55832, 99978, 41665, 69914, 113685, 49279, 84045, 127270],
    );
    expect(
      SubscriptionService.getPlansForBusinessType('retail').first.price,
      23750,
    );
  });
}