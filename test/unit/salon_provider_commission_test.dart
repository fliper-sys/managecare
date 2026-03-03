import 'package:flutter_test/flutter_test.dart';
import '../../lib/presentation/industry_specific/salon/providers/salon_provider.dart';

void main() {
  test('computeStylistCommission calculates commission correctly', () {
    final stylist = Stylist(
      id: 's1',
      name: 'Alex',
      email: 'alex@example.com',
      phone: null,
      specialization: 'stylist',
      serviceIds: [],
      commissionPercentage: 10.0,
      createdAt: DateTime.now(),
    );

    final appt1 = SalonAppointment(
      id: 'a1',
      clientName: 'Client A',
      clientPhone: '000',
      clientEmail: 'a@a.com',
      serviceId: 'svc1',
      serviceName: 'Service 1',
      servicePrice: 100.0,
      stylistId: 's1',
      stylistName: 'Alex',
      appointmentTime: DateTime.now(),
      durationMinutes: 60,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    final appt2 = SalonAppointment(
      id: 'a2',
      clientName: 'Client B',
      clientPhone: '111',
      clientEmail: 'b@b.com',
      serviceId: 'svc2',
      serviceName: 'Service 2',
      servicePrice: 200.0,
      stylistId: 's1',
      stylistName: 'Alex',
      appointmentTime: DateTime.now(),
      durationMinutes: 45,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    final total = SalonProvider.computeStylistCommission(stylist, [appt1, appt2]);

    // 10% of (100 + 200) = 30
    expect(total, closeTo(30.0, 0.001));
  });
}
