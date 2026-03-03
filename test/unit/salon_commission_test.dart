import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/presentation/industry_specific/salon/providers/salon_provider.dart';

void main() {
  test('getStylistCommissionTotalForPeriod computes commission correctly', () {
    final provider = SalonProvider();

    final stylist = Stylist(
      id: 's1',
      name: 'Alice',
      email: 'alice@example.com',
      phone: null,
      specialization: 'stylist',
      serviceIds: [],
      commissionPercentage: 20.0,
      createdAt: DateTime.now(),
    );

    final now = DateTime.now();
    final appts = List.generate(3, (i) {
      return SalonAppointment(
        id: 'a$i',
        clientName: 'Client $i',
        clientPhone: '000',
        clientEmail: 'c$i@example.com',
        serviceId: 'svc$i',
        serviceName: 'Service $i',
        servicePrice: 100.0,
        stylistId: 's1',
        stylistName: 'Alice',
        appointmentTime: now.subtract(Duration(hours: i)),
        durationMinutes: 60,
        status: 'completed',
        createdAt: now.subtract(Duration(hours: i)),
      );
    });

    provider.setStylistsForTesting([stylist]);
    provider.setAppointmentsForTesting(appts);

    final start = now.subtract(const Duration(days: 1));
    final end = now.add(const Duration(days: 1));

    final total = provider.getStylistCommissionTotalForPeriod('s1', start, end);
    expect(total, 3 * 100.0 * 0.20);
  });

  test('getStylistCommissionTotalForPeriod returns 0 for stylist with no completed appointments', () {
    final provider = SalonProvider();

    final stylist = Stylist(
      id: 's2',
      name: 'Bob',
      email: 'bob@example.com',
      phone: null,
      specialization: 'stylist',
      serviceIds: [],
      commissionPercentage: 15.0,
      createdAt: DateTime.now(),
    );

    provider.setStylistsForTesting([stylist]);
    provider.setAppointmentsForTesting([]);

    final start = DateTime.now().subtract(const Duration(days: 1));
    final end = DateTime.now().add(const Duration(days: 1));

    final total = provider.getStylistCommissionTotalForPeriod('s2', start, end);
    expect(total, 0.0);
  });
}
