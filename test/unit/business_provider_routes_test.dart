import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/providers/business_provider.dart';

void main() {
  test('maps barber and barbershop to /barbershop', () {
    expect(BusinessProvider.industryRouteForType('barber'), '/barbershop');
    expect(BusinessProvider.industryRouteForType('Barbershop'), '/barbershop');
  });

  test('maps wholesale to /wholesale', () {
    expect(BusinessProvider.industryRouteForType('wholesale'), '/wholesale');
  });
}
