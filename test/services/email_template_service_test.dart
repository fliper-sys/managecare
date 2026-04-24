import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/email_template_service.dart';

void main() {
  test('Receipt HTML contains product names from items', () {
    final items = [
      {'name': 'Premium Layer Feed', 'quantity': 2, 'price': 2500},
      {'name': 'Vitamin Supplements', 'quantity': 1, 'price': 1500},
    ];

    final html = EmailTemplateService.generateReceiptEmailHtml(
      businessName: 'Test Farm',
      businessLogo: null,
      businessContact: '08000000000',
      receiptNumber: 'RCPT-123',
      receiptDate: DateTime(2025, 1, 1),
      customerName: 'John Doe',
      items: items,
      subtotal: 6500.0,
      tax: 0.0,
      total: 6500.0,
      paymentMethod: 'Cash',
      customHeader: null,
      customFooter: null,
    );

    expect(html.contains('Premium Layer Feed'), isTrue);
    expect(html.contains('Vitamin Supplements'), isTrue);
    expect(html.contains('RCPT-123'), isTrue);
  });

  test('Worker invitation HTML includes credentials and business details', () {
    final html = EmailTemplateService.generateWorkerInvitationEmailHtml(
      businessName: 'Corner Store',
      workerName: 'Ada Lovelace',
      role: 'Cashier',
      email: 'ada@example.com',
      temporaryPassword: 'Temp1234',
    );

    expect(html.contains('Corner Store'), isTrue);
    expect(html.contains('Ada Lovelace'), isTrue);
    expect(html.contains('Temp1234'), isTrue);
  });

  test('Subscription status HTML includes plan and state', () {
    final html = EmailTemplateService.generateSubscriptionStatusEmailHtml(
      businessName: 'Blue Pharmacy',
      recipientName: 'Mary',
      planName: 'Professional Monthly',
      amount: 15000,
      statusLabel: 'Pending Approval',
      statusMessage: 'Your request is awaiting review.',
      requestId: 'REQ-001',
      startsOn: DateTime(2026, 4, 24),
      endsOn: DateTime(2026, 5, 24),
    );

    expect(html.contains('Blue Pharmacy'), isTrue);
    expect(html.contains('Professional Monthly'), isTrue);
    expect(html.contains('Pending Approval'), isTrue);
    expect(html.contains('REQ-001'), isTrue);
  });

  test('Rent receipt HTML includes property and payment details', () {
    final html = EmailTemplateService.generateRentReceiptEmailHtml(
      businessName: 'Prime Estates',
      tenantName: 'John Doe',
      propertyTitle: 'Lekki Apartment 4B',
      amount: 250000,
      paymentMethod: 'transfer',
      paidDate: DateTime(2026, 4, 24, 10, 30),
      durationMonths: 2,
      receiptUrl: 'https://example.com/receipt.pdf',
    );

    expect(html.contains('Prime Estates'), isTrue);
    expect(html.contains('Lekki Apartment 4B'), isTrue);
    expect(html.contains('transfer'), isTrue);
    expect(html.contains('Open Uploaded Receipt'), isTrue);
  });
}
