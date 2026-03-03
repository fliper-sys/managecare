import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:business_manager/providers/auto_provider.dart';
import 'package:business_manager/presentation/industry_specific/auto/screens/create_service_order_screen.dart';

void main() {
  testWidgets('create button validates vehicle selection', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AutoProvider>(
          create: (_) => AutoProvider(),
          child: const CreateServiceOrderScreen(),
        ),
      ),
    );

    // Tap the create button without selecting a vehicle
    final createBtn = find.widgetWithText(ElevatedButton, 'Create Service Order');
    expect(createBtn, findsOneWidget);
    // Make sure button is visible (scroll into view) before tapping in tests.
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // SnackBar with validation should be shown
    expect(find.text('Select a vehicle'), findsOneWidget);
  });
}
