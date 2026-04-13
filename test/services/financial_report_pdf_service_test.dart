import 'package:business_manager/services/financial_report_pdf_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void _ensureBinding() {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (_) {}
}

void main() {
  group('FinancialReportPdfService', () {
    test('buildPdfBytes returns a non-empty pdf document', () async {
      _ensureBinding();

      final bytes = await FinancialReportPdfService.buildPdfBytes(
        data: FinancialReportPdfData(
          businessName: 'Test Business',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
          generatedAt: DateTime(2026, 2, 1, 10, 30),
          generatedBy: 'Owner',
          totalRevenue: 250000,
          totalCogs: 85000,
          totalOperatingExpenses: 45000,
          grossProfit: 165000,
          netProfit: 120000,
          grossMargin: 66.0,
          netProfitMargin: 48.0,
          inventoryValue: 90000,
          inventoryItemCount: 24,
          periods: const [
            FinancialReportPeriodRow(
              label: 'Jan',
              revenue: 250000,
              cogs: 85000,
              operatingExpenses: 45000,
              salariesEstimate: 27000,
              utilitiesEstimate: 18000,
            ),
          ],
          transactions: const [
            FinancialReportTransactionRow(
              date: DateTime(2026, 1, 20),
              description: 'Hair products bundle',
              type: 'Sale',
              amount: 35000,
              paymentMethod: 'card',
              cashier: 'Mimi',
              itemCount: 3,
            ),
          ],
          paymentBreakdown: const {
            'cash': 120000,
            'card': 80000,
            'transfer': 50000,
          },
        ),
        options: const FinancialReportPdfOptions(
          includeTransactions: true,
        ),
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));
    });
  });
}
