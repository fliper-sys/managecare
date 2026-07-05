import 'package:business_manager/services/notification_and_email_service.dart' show NotificationAndEmailService;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:business_manager/providers/retail_provider.dart';
import 'package:business_manager/presentation/industry_specific/gas/screens/gas_pump_screen.dart';
import 'package:business_manager/providers/business_provider.dart';
import 'package:business_manager/data/models/business_model.dart';
import 'package:business_manager/data/repositories/business_repository_impl.dart';
import 'package:business_manager/providers/receipt_settings_provider.dart';
import 'package:business_manager/providers/auth_provider.dart';

// A small TestBusinessRepository that returns a single business (so BusinessProvider.currentBusiness is set)
class TestBusinessRepository extends BusinessRepository {
  TestBusinessRepository() : super();

  @override
  Future<List<BusinessModel>> getUserBusinesses(String userId) async => [
        BusinessModel(
          id: 'testbiz',
          name: 'Test Gas Station',
          businessType: 'gas',
          ownerId: userId,
          createdAt: DateTime.now(),
        )
      ];

  // Unused for this test - implement stubs matching base signatures
  @override
  Future<void> createBusiness(BusinessModel business) async {}

  @override
  Future<void> updateBusiness(BusinessModel business) async {}
}

// A tiny TestRetailProvider that overrides the products getter and fuelSale
class TestRetailProvider extends RetailProvider {
  final List<Product> _testProducts;

  TestRetailProvider(this._testProducts)
      : super(
          firestore: FakeFirebaseFirestore(),
          notificationEmailService: NotificationAndEmailService(firestore: FakeFirebaseFirestore()),
        );

  @override
  List<Product> get products => _testProducts;

  @override
  Future<Map<String, dynamic>> fuelSale({
    required String productId,
    double? amountPaid,
    double? quantity,
    required String paymentMethod,
    String? workerId,
    String? workerName,
    String? customerEmail,
    String? customerName,
    String? storeId,
    String? pumpId,
    String? pumpNumber,
    String? pumpName,
  }) async {
    // Simulate a quick network/db write and return a sale map
    await Future.delayed(const Duration(milliseconds: 10));
    final unitPrice = 200.0;
    final q = quantity ?? (amountPaid != null ? (amountPaid / unitPrice) : 1.0);
    final total = (amountPaid ?? (q * unitPrice)).toDouble();
    return {
      'id': 'sale1',
      'items': [
        {'productId': productId, 'productName': 'Petrol', 'quantity': q, 'unitPrice': unitPrice, 'total': total}
      ],
      'total': total,
      'quantity': q,
    };
  }
}

void main() {
  testWidgets('PostSaleActionSheet appears immediately after fuelSale', (WidgetTester tester) async {
    // Prepare providers
    final retail = TestRetailProvider([
      Product(id: 'petrol', name: 'Petrol', price: 200.0, stock: 1000, category: 'Fuel', unit: 'L'),
    ]);

    final businessRepo = TestBusinessRepository();
    final businessProvider = BusinessProvider(repository: businessRepo);
    await businessProvider.loadUserBusinesses('user1'); // sets current business

    // Build the widget tree with necessary providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider< BusinessProvider >.value(value: businessProvider),
          ChangeNotifierProvider< RetailProvider >.value(value: retail),
          ChangeNotifierProvider< ReceiptSettingsProvider >(create: (_) => ReceiptSettingsProvider()),
          ChangeNotifierProvider< AuthProvider >(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: GasPumpScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Enter an amount to sell by amount using semantics label (stable in tests)
    final amountField = find.bySemanticsLabel('Amount to Pay');
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '1000');
    await tester.pumpAndSettle();

    // Tap Confirm Sale
    final confirmButton = find.widgetWithText(ElevatedButton, 'Confirm Sale');
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pump();

    // Payment method sheet should appear - confirm it
    final confirmPayment = find.widgetWithText(ElevatedButton, 'Confirm Payment');
    expect(confirmPayment, findsOneWidget);
    await tester.tap(confirmPayment);

    // Wait for a short period and pump frames so the post-sale action sheet can be displayed
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // The PostSaleActionSheet contains the heading 'Receipt Actions'
    expect(find.text('Receipt Actions'), findsOneWidget);
  });
}
