import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:business_manager/presentation/industry_specific/barber_shop/providers/barber_shop_provider.dart';
import 'package:business_manager/presentation/industry_specific/barber_shop/screens/barber_commission_screen.dart';

class TestBarberProvider extends BarberShopProvider {
  TestBarberProvider();

  List<Barber> testBarbers = [];

  @override
  List<Barber> get barbers => testBarbers;

  @override
  Future<void> loadBarbers() async {
    // no-op for widget tests
  }

  @override
  Future<void> loadSales() async {
    // no-op
  }

  @override
  Future<void> loadAppointments() async {
    // no-op
  }

  @override
  double getBarberCommissionTotal(String barberId) {
    final barber = testBarbers.firstWhere((b) => b.id == barberId);
    final pct = barber.commissionPercentage ?? 0.0;
    if (pct <= 0.0) return 0.0;
    final completed = appointments.where((a) => a.barberId == barberId && a.status == 'completed');
    final total = completed.fold<double>(0.0, (sum, a) {
      final amount = (a.amountPaid != null && a.amountPaid! > 0) ? a.amountPaid! : a.servicePrice;
      return sum + amount * (pct / 100.0);
    });
    return total;
  }
}

void main() {
  testWidgets('BarberCommissionScreen shows barber completed bookings and commission', (tester) async {
    final provider = TestBarberProvider();

    final barber = Barber(
      id: 'b1',
      name: 'John Doe',
      email: 'john@example.com',
      phone: '555',
      specialization: 'Senior',
      serviceIds: [],
      commissionPercentage: 20.0,
      createdAt: DateTime.now(),
    );

    final appointment = BarberShopAppointment(
      id: 'a1',
      clientName: 'ClientX',
      clientPhone: '000',
      serviceId: 'svc',
      serviceName: 'Shave',
      servicePrice: 200.0,
      barberId: 'b1',
      barberName: 'John Doe',
      appointmentTime: DateTime.now(),
      durationMinutes: 20,
      status: 'completed',
      amountPaid: 200.0,
      createdAt: DateTime.now(),
    );

    provider.testBarbers = [barber];
    provider.setAppointmentsForTesting([appointment]);

    await tester.pumpWidget(
      ChangeNotifierProvider<BarberShopProvider>.value(
        value: provider,
        child: const MaterialApp(home: BarberCommissionScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);

    // Expand to show completed bookings
    await tester.tap(find.text('John Doe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shave'), findsOneWidget);
    expect(find.textContaining('Comm: ₦40.00'), findsOneWidget);
  });
}