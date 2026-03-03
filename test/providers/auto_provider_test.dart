import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/providers/auto_provider.dart';

void main() {
  group('AutoProvider', () {
    test('setBusinessId clears and reinitializes sample data', () {
      final p = AutoProvider();
      // Ensure sample data is initialized for the test
      p.initSampleData();
      expect(p.vehicles.length, greaterThan(0));
      // mutate state
      p.addVehicle(Vehicle(
          id: 'newv', make: 'F', model: 'G', licensePlate: 'LP', vin: 'V', year: 2021, ownerName: 'A', ownerPhone: 'P'));
      expect(p.getVehicleById('newv'), isNotNull);

      p.setBusinessId('b1');
      // After switching business, previously added vehicle should be gone
      expect(p.getVehicleById('newv'), isNull);
      expect(p.vehicles.length, greaterThan(0));

      // switching to the same business won't reinit
      final len = p.vehicles.length;
      p.setBusinessId('b1');
      expect(p.vehicles.length, equals(len));
    });

    test('createJob calculates totals and deducts parts inventory', () {
      final p = AutoProvider();
      final service = p.services.first;
      final part = p.parts.first;
      final initialPartQty = part.quantity;

      final job = Job(
        id: 't1',
        vehicleId: p.vehicles.first.id,
        createdAt: DateTime.now(),
        tasks: [service],
        usedParts: [Part(id: part.id, name: part.name, quantity: 2, cost: part.cost)],
      );

      p.createJob(job);
      final created = p.jobs.firstWhere((j) => j.id == 't1');
      expect(created.totalCost, equals(service.laborCost + (part.cost * 2)));

      final invPart = p.parts.firstWhere((x) => x.id == part.id);
      expect(invPart.quantity, equals(initialPartQty - 2));
    });

    test('addPartToJob decreases inventory and updates job total', () {
      final p = AutoProvider();
      final job = Job(id: 't2', vehicleId: p.vehicles.first.id, createdAt: DateTime.now());
      p.createJob(job);

      final part = p.parts.first;
      final beforeQty = part.quantity;
      p.addPartToJob('t2', part, quantity: 1);

      final updatedJob = p.jobs.firstWhere((j) => j.id == 't2');
      expect(updatedJob.usedParts.any((u) => u.id == part.id), isTrue);
      expect(p.parts.firstWhere((x) => x.id == part.id).quantity, equals(beforeQty - 1));
    });
  });
}
