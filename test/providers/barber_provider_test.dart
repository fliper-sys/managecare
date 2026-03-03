import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:business_manager/presentation/industry_specific/barber_shop/providers/barber_shop_provider.dart';

void main() {
  group('BarberShopProvider utilities', () {
    test('getTodayAppointments includes appointment at start of day and excludes next day', () {
      final provider = BarberShopProvider(firestore: FakeFirebaseFirestore());
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final inRange = BarberShopAppointment(
        id: 'a1',
        clientName: 'Test',
        clientPhone: '000',
        serviceId: 's1',
        serviceName: 'Cut',
        servicePrice: 10.0,
        barberId: 'b1',
        barberName: 'Barber',
        appointmentTime: start.add(const Duration(hours: 10)),
        durationMinutes: 30,
        status: 'pending',
        notes: null,
        createdAt: DateTime.now(),
      );

      final outOfRange = BarberShopAppointment(
        id: 'a2',
        clientName: 'Test2',
        clientPhone: '000',
        serviceId: 's2',
        serviceName: 'Shave',
        servicePrice: 8.0,
        barberId: 'b2',
        barberName: 'Barber2',
        appointmentTime: start.add(const Duration(days: 1)),
        durationMinutes: 30,
        status: 'pending',
        notes: null,
        createdAt: DateTime.now(),
      );

      provider.setAppointmentsForTesting([inRange, outOfRange]);
      final todays = provider.getTodayAppointments();
      expect(todays.length, 1);
      expect(todays.first.id, 'a1');
    });

    test('appointment at midnight included', () {
      final provider = BarberShopProvider(firestore: FakeFirebaseFirestore());
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final midnightAppt = BarberShopAppointment(
        id: 'm1',
        clientName: 'Mid',
        clientPhone: '000',
        serviceId: 's1',
        serviceName: 'Cut',
        servicePrice: 10.0,
        barberId: 'b1',
        barberName: 'Barber',
        appointmentTime: start,
        durationMinutes: 30,
        status: 'pending',
        notes: null,
        createdAt: DateTime.now(),
      );

      provider.setAppointmentsForTesting([midnightAppt]);
      final todays = provider.getTodayAppointments();
      expect(todays.length, 1);
    });
  });
}
