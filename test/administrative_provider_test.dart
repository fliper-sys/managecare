import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/presentation/industry_specific/administrative/providers/administrative_provider.dart';

void main() {
  group('AdministrativeProvider', () {
    test('moves an assigned document through submission and approval', () {
      final provider = AdministrativeProvider();

      provider.assignDocument(
        documentName: 'VAT Report.pdf',
        clientName: 'Care Home',
        assignedTo: 'Sarah Daniels',
        note: 'Reconcile the VAT figures before submission.',
      );
      final task = provider.tasks.first;

      expect(task.status, AdministrativeTaskStatus.assigned);
      expect(task.documentName, 'VAT Report.pdf');

      provider.startTask(task.id);
      provider.submitTask(task.id, 'VAT Report Updated.pdf');
      provider.reviewTask(task.id, approved: true, storageAction: 'new_version');

      expect(task.status, AdministrativeTaskStatus.approved);
      expect(task.submittedFileName, 'VAT Report Updated.pdf');
      expect(task.reviewStorageAction, 'new_version');
    });

    test('trailing obligations calculate from the completion date', () {
      final provider = AdministrativeProvider();

      provider.createObligation(
        title: 'Monthly VAT filing',
        clientName: 'Care Home',
        countdownType: AdministrativeCountdownType.trailing,
        intervalDays: 30,
      );
      final obligation = provider.obligations.first;
      final beforeCompletion = DateTime.now();

      provider.completeObligation(obligation.id);

      expect(obligation.isCompleted, isTrue);
      expect(obligation.dueAt.isAfter(beforeCompletion.add(const Duration(days: 29))), isTrue);
      expect(obligation.dueAt.isBefore(beforeCompletion.add(const Duration(days: 31))), isTrue);
    });
  });
}
