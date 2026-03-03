import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:business_manager/presentation/industry_specific/salon/providers/salon_provider.dart';
import 'package:business_manager/presentation/industry_specific/salon/screens/commission_screen.dart';

class TestSalonProvider extends SalonProvider {
  TestSalonProvider();
  @override
  Future<void> loadStylists() async {
    // no-op for widget tests
  }

  @override
  Future<void> loadAppointments() async {
    // no-op for widget tests
  }
}

void main() {
  testWidgets('CommissionScreen shows stylist, owed amounts and completed bookings', (tester) async {
    final provider = TestSalonProvider();
    final stylist = Stylist(
      id: 's1',
      name: 'Jane Doe',
      email: 'jane@example.com',
      phone: '123',
      specialization: 'Hairdresser',
      serviceIds: [],
      commissionPercentage: 20.0,
      createdAt: DateTime.now(),
    );

    final appointment = SalonAppointment(
      id: 'a1',
      clientName: 'Client',
      clientPhone: '000',
      clientEmail: 'c@example.com',
      serviceId: 'svc',
      serviceName: 'Cut',
      servicePrice: 100.0,
      stylistId: 's1',
      stylistName: 'Jane Doe',
      appointmentTime: DateTime.now(),
      durationMinutes: 30,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    provider.setStylistsForTesting([stylist]);
    provider.setAppointmentsForTesting([appointment]);

    await tester.pumpWidget(
      ChangeNotifierProvider<SalonProvider>.value(
        value: provider,
        child: const MaterialApp(home: CommissionScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.textContaining('₦'), findsWidgets);
    expect(find.text('Total Commission Owed'), findsOneWidget);

    // Expand the stylist tile to show completed bookings
    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    // Booking details and commission should be visible
    expect(find.textContaining('Cut'), findsOneWidget);
    expect(find.textContaining('Comm: ₦20.00'), findsOneWidget);
  });
}
