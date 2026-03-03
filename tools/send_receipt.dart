import 'dart:io';

import 'package:business_manager/services/email_service.dart';

Future<void> main() async {
  final service = EmailService();

  print('Sending receipt via EmailService.sendReceiptEmail...');

  final ok = await service.sendReceiptEmail(
    recipient: 'lovebari4@icloud.com',
    businessName: 'Manage Care Test (Dart Script)',
    receiptText: 'This is a test receipt sent from a local Dart script',
    orderId: 'CLI-TEST-002',
    businessId: 'TESTBUS',
    businessEmail: 'owner@example.com',
    businessPhone: '+1234567890',
    customerName: 'Test Customer',
    logoUrl:
        'https://globalthrivealliance.com/emailtemplate/uploads/693c42e26ebec_tmp_test.gif',
    isPro: true,
    generatePDF: true,
    sendCopyToSender: true,
    theme: 'professional',
    receiptType: 'detailed',
  );

  print('EmailService.sendReceiptEmail returned: $ok');
  exit(ok ? 0 : 2);
}

