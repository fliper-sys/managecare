/// Service for generating beautiful CSS-formatted email templates
/// Works with the web server's receipt_template.php and template_renderer.php
library;

import 'package:intl/intl.dart';

class EmailTemplateService {
  static const String baseUrl =
      'https://globalthrivealliance.com/emailtemplate';

  /// Generate receipt email HTML with CSS styling and business branding
  static String generateReceiptEmailHtml({
    required String businessName,
    required String? businessLogo,
    required String? businessContact,
    required String receiptNumber,
    required DateTime receiptDate,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double total,
    required String paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    required String? customHeader,
    required String? customFooter,
  }) {
    final formatter = DateFormat('MMM dd, yyyy - hh:mm a');
    final formattedDate = formatter.format(receiptDate);
    final currencyFormatter = NumberFormat.currency(symbol: '₦');

    // Build items HTML
    final itemsHtml = items.map((item) {
      final quantity = item['quantity'] ?? 1;
      final unitPrice = double.tryParse(item['price'].toString()) ?? 0;
      final lineTotal = quantity * unitPrice;
      return '''
      <tr>
        <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: left; font-size: 13px;">
          ${item['name'] ?? 'Item'}
        </td>
        <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: center; font-size: 13px;">
          $quantity
        </td>
        <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right; font-size: 13px;">
          ${currencyFormatter.format(unitPrice)}
        </td>
        <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right; font-size: 13px; font-weight: 600;">
          ${currencyFormatter.format(lineTotal)}
        </td>
      </tr>
      ''';
    }).join('');

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Receipt #$receiptNumber</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                background-color: #f7f9fc;
                color: #333;
                line-height: 1.6;
            }
            
            .container {
                max-width: 600px;
                margin: 0 auto;
                background-color: #ffffff;
                padding: 40px 30px;
                border-radius: 8px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
            
            .header {
                text-align: center;
                border-bottom: 3px solid #10B981;
                padding-bottom: 20px;
                margin-bottom: 30px;
            }
            
            .logo {
                max-width: 120px;
                height: auto;
                margin-bottom: 10px;
                border-radius: 4px;
            }
            
            .business-name {
                font-size: 24px;
                font-weight: 700;
                color: #1f2937;
                margin-bottom: 5px;
            }
            
            .business-contact {
                font-size: 12px;
                color: #6b7280;
                line-height: 1.8;
            }
            
            .receipt-title {
                font-size: 18px;
                font-weight: 600;
                color: #10B981;
                margin-bottom: 5px;
            }
            
            .receipt-number {
                font-size: 12px;
                color: #6b7280;
                font-family: 'Courier New', monospace;
                letter-spacing: 1px;
            }
            
            .custom-header {
                background-color: #f0f9ff;
                border-left: 4px solid #10B981;
                padding: 12px 15px;
                margin: 20px 0;
                border-radius: 4px;
                font-size: 13px;
                color: #1f2937;
                font-style: italic;
            }
            
            .section-title {
                font-size: 12px;
                font-weight: 700;
                text-transform: uppercase;
                color: #6b7280;
                letter-spacing: 0.5px;
                margin: 20px 0 10px;
                border-bottom: 2px solid #e5e7eb;
                padding-bottom: 8px;
            }
            
            .customer-info {
                background-color: #f9fafb;
                padding: 15px;
                border-radius: 4px;
                margin: 15px 0;
                font-size: 13px;
            }
            
            .customer-label {
                color: #6b7280;
                font-size: 11px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 3px;
            }
            
            .customer-value {
                color: #1f2937;
                font-weight: 500;
            }
            
            .items-table {
                width: 100%;
                border-collapse: collapse;
                margin: 15px 0;
            }
            
            .items-table th {
                background-color: #f3f4f6;
                padding: 12px 8px;
                text-align: left;
                font-size: 12px;
                font-weight: 700;
                color: #374151;
                border-bottom: 2px solid #e5e7eb;
                text-transform: uppercase;
                letter-spacing: 0.3px;
            }
            
            .items-table th:nth-child(2),
            .items-table th:nth-child(3),
            .items-table th:nth-child(4) {
                text-align: right;
            }
            
            .items-table td {
                padding: 8px;
                border-bottom: 1px solid #eee;
                font-size: 13px;
            }
            
            .items-table td:nth-child(2),
            .items-table td:nth-child(3),
            .items-table td:nth-child(4) {
                text-align: right;
            }
            
            .summary-row {
                display: flex;
                justify-content: space-between;
                padding: 12px 0;
                font-size: 13px;
                border-bottom: 1px solid #eee;
            }
            
            .summary-row.total {
                border-bottom: 3px solid #10B981;
                padding: 15px 0;
                margin-top: 5px;
                font-size: 16px;
                font-weight: 700;
                color: #10B981;
            }
            
            .summary-label {
                color: #6b7280;
                text-align: left;
            }
            
            .summary-value {
                color: #1f2937;
                font-weight: 600;
                text-align: right;
            }
            
            .summary {
                background-color: #f9fafb;
                padding: 15px;
                border-radius: 4px;
                margin: 20px 0;
            }
            
            .payment-method {
                background-color: #ecfdf5;
                border: 1px solid #10B981;
                padding: 12px 15px;
                border-radius: 4px;
                margin: 15px 0;
                font-size: 13px;
            }
            
            .payment-method-label {
                font-size: 11px;
                color: #059669;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 3px;
                font-weight: 600;
            }
            
            .payment-method-value {
                color: #047857;
                font-weight: 600;
                font-size: 14px;
            }
            
            .custom-footer {
                background-color: #fef3c7;
                border-left: 4px solid #f59e0b;
                padding: 12px 15px;
                margin: 20px 0;
                border-radius: 4px;
                font-size: 13px;
                color: #92400e;
                font-style: italic;
            }
            
            .footer {
                text-align: center;
                border-top: 2px solid #e5e7eb;
                padding-top: 20px;
                margin-top: 30px;
                font-size: 12px;
                color: #6b7280;
            }
            
            .footer-text {
                margin: 5px 0;
            }
            
            .footer-separator {
                height: 1px;
                background-color: #e5e7eb;
                margin: 15px 0;
            }
            
            .divider {
                height: 1px;
                background-color: #e5e7eb;
                margin: 20px 0;
            }
            
            @media only screen and (max-width: 480px) {
                .container {
                    padding: 20px 15px;
                }
                
                .business-name {
                    font-size: 18px;
                }
                
                .items-table th,
                .items-table td {
                    padding: 6px 4px;
                    font-size: 12px;
                }
                
                .summary-row {
                    font-size: 12px;
                    padding: 8px 0;
                }
            }
        </style>
    </head>
    <body>
        <div class="container">
            <!-- Header -->
            <div class="header">
                ${businessLogo != null && businessLogo.isNotEmpty ? '<img src="$businessLogo" alt="Business Logo" class="logo">' : ''}
                <div class="business-name">$businessName</div>
                ${businessContact != null && businessContact.isNotEmpty ? '<div class="business-contact">$businessContact</div>' : ''}
                <div class="receipt-title">RECEIPT</div>
                <div class="receipt-number">#$receiptNumber</div>
                <div class="receipt-number">$formattedDate</div>
            </div>
            
            <!-- Custom Header Note -->
            ${customHeader != null && customHeader.isNotEmpty ? '<div class="custom-header">$customHeader</div>' : ''}
            
            <!-- Customer Information -->
            <div class="customer-info">
                <div class="customer-label">Customer Name</div>
                <div class="customer-value">$customerName</div>
            </div>
            
            <!-- Items -->
            <div class="section-title">Order Items</div>
            <table class="items-table">
                <thead>
                    <tr>
                        <th>Item</th>
                        <th>Qty</th>
                        <th>Unit Price</th>
                        <th>Total</th>
                    </tr>
                </thead>
                <tbody>
                    $itemsHtml
                </tbody>
            </table>
            
            <!-- Summary -->
            <div class="summary">
                <div class="summary-row">
                    <span class="summary-label">Subtotal:</span>
                    <span class="summary-value">${currencyFormatter.format(subtotal)}</span>
                </div>
                ${tax > 0 ? '''
                <div class="summary-row">
                    <span class="summary-label">Tax:</span>
                    <span class="summary-value">${currencyFormatter.format(tax)}</span>
                </div>
                ''' : ''}
                <div class="summary-row total">
                    <span class="summary-label">Total Amount:</span>
                    <span class="summary-value">${currencyFormatter.format(total)}</span>
                </div>
            </div>
            
            <!-- Payment Method / Breakdown -->
            ${paymentBreakdown != null && paymentBreakdown.isNotEmpty ? '''
            <div class="payment-method">
                <div class="payment-method-label">Payments</div>
                <div style="margin-top:8px;">
                  ${paymentBreakdown.map((pb) {
                    final method = (pb['method'] ?? '').toString().toUpperCase();
                    final tx = (pb['transactionId'] ?? '').toString();
                    final amount = double.tryParse((pb['amount'] ?? 0.0).toString()) ?? 0.0;
                    return '<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid #f3f4f6;font-size:13px;"><span style="font-weight:600;color:#047857;">$method ${tx.isNotEmpty ? ' • $tx' : ''}</span><span style="font-weight:600;">${currencyFormatter.format(amount)}</span></div>';
                  }).join('')}
                </div>
            </div>
            ''' : '''
            <div class="payment-method">
                <div class="payment-method-label">Payment Method</div>
                <div class="payment-method-value">${paymentMethod.toUpperCase()}</div>
            </div>
            '''}
            
            <!-- Custom Footer Note -->
            ${customFooter != null && customFooter.isNotEmpty ? '<div class="custom-footer">$customFooter</div>' : ''}
            
            <!-- Footer -->
            <div class="footer">
                <div class="footer-text">Thank you for your purchase!</div>
                <div class="footer-separator"></div>
                <div class="footer-text">This is an automated receipt. Please keep it for your records.</div>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Generate sales notification email HTML for business owner
  static String generateSalesNotificationHtml({
    required String businessName,
    required String customerName,
    required String? customerEmail,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String receiptNumber,
    required DateTime saleTime,
  }) {
    final formatter = DateFormat('MMM dd, yyyy - hh:mm a');
    final formattedDate = formatter.format(saleTime);
    final currencyFormatter = NumberFormat.currency(symbol: '₦');

    final itemsList = items.map((item) {
      final quantity = item['quantity'] ?? 1;
      return '${item['name']} (x$quantity)';
    }).join('<br>');

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>New Sale - $businessName</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                background-color: #f7f9fc;
                color: #333;
            }
            
            .container {
                max-width: 600px;
                margin: 0 auto;
                background-color: #ffffff;
                padding: 30px;
                border-radius: 8px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
            
            .alert {
                background-color: #ecfdf5;
                border: 2px solid #10B981;
                border-radius: 6px;
                padding: 20px;
                margin-bottom: 25px;
            }
            
            .alert-icon {
                font-size: 32px;
                text-align: center;
                margin-bottom: 10px;
            }
            
            .alert-title {
                font-size: 20px;
                font-weight: 700;
                color: #047857;
                text-align: center;
                margin-bottom: 5px;
            }
            
            .alert-amount {
                font-size: 28px;
                font-weight: 700;
                color: #10B981;
                text-align: center;
            }
            
            .info-section {
                background-color: #f9fafb;
                padding: 15px;
                border-radius: 6px;
                margin-bottom: 15px;
            }
            
            .info-label {
                font-size: 11px;
                font-weight: 700;
                text-transform: uppercase;
                color: #6b7280;
                letter-spacing: 0.5px;
                margin-bottom: 5px;
            }
            
            .info-value {
                font-size: 14px;
                font-weight: 600;
                color: #1f2937;
            }
            
            .items-section {
                margin: 20px 0;
            }
            
            .section-title {
                font-size: 12px;
                font-weight: 700;
                text-transform: uppercase;
                color: #374151;
                letter-spacing: 0.5px;
                margin-bottom: 10px;
                border-bottom: 2px solid #e5e7eb;
                padding-bottom: 8px;
            }
            
            .items-list {
                font-size: 13px;
                color: #4b5563;
                line-height: 1.8;
            }
            
            .footer {
                text-align: center;
                border-top: 1px solid #e5e7eb;
                padding-top: 15px;
                margin-top: 20px;
                font-size: 12px;
                color: #6b7280;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <!-- Alert Box -->
            <div class="alert">
                <div class="alert-icon">✅</div>
                <div class="alert-title">New Sale Recorded</div>
                <div class="alert-amount">${currencyFormatter.format(totalAmount)}</div>
            </div>
            
            <!-- Sale Details -->
            <div class="info-section">
                <div class="info-label">Receipt Number</div>
                <div class="info-value">#$receiptNumber</div>
            </div>
            
            <div class="info-section">
                <div class="info-label">Customer Name</div>
                <div class="info-value">$customerName</div>
            </div>
            
            ${customerEmail != null && customerEmail.isNotEmpty ? '''
            <div class="info-section">
                <div class="info-label">Customer Email</div>
                <div class="info-value">$customerEmail</div>
            </div>
            ''' : ''}
            
            <!-- Items -->
            <div class="items-section">
                <div class="section-title">Items Sold</div>
                <div class="items-list">
                    $itemsList
                </div>
            </div>
            
            <!-- More Info -->
            <div class="info-section">
                <div class="info-label">Payment Method</div>
                <div class="info-value">${paymentMethod.toUpperCase()}</div>
            </div>
            
            <div class="info-section">
                <div class="info-label">Sale Time</div>
                <div class="info-value">$formattedDate</div>
            </div>
            
            <!-- Footer -->
            <div class="footer">
                <p>This is an automated notification from your $businessName point-of-sale system.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Generate payment reminder email HTML
  static String generatePaymentReminderHtml({
    required String businessName,
    required String customerName,
    required double amount,
    required DateTime dueDate,
    required String invoiceNumber,
  }) {
    final formatter = DateFormat('MMM dd, yyyy');
    final formattedDueDate = formatter.format(dueDate);
    final currencyFormatter = NumberFormat.currency(symbol: '₦');

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Reminder - $businessName</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background-color: #f7f9fc;
            }
            
            .container {
                max-width: 600px;
                margin: 0 auto;
                background-color: #ffffff;
                padding: 30px;
                border-radius: 8px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
            
            .warning-banner {
                background-color: #fef3c7;
                border-left: 4px solid #f59e0b;
                padding: 15px;
                border-radius: 4px;
                margin-bottom: 20px;
            }
            
            .warning-title {
                color: #d97706;
                font-weight: 700;
                font-size: 14px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 5px;
            }
            
            .warning-text {
                color: #92400e;
                font-size: 13px;
            }
            
            .header {
                text-align: center;
                margin-bottom: 25px;
            }
            
            .business-name {
                font-size: 24px;
                font-weight: 700;
                color: #1f2937;
                margin-bottom: 5px;
            }
            
            .info-grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 15px;
                margin: 20px 0;
            }
            
            .info-box {
                background-color: #f9fafb;
                padding: 15px;
                border-radius: 6px;
            }
            
            .info-label {
                font-size: 11px;
                font-weight: 700;
                text-transform: uppercase;
                color: #6b7280;
                letter-spacing: 0.5px;
                margin-bottom: 5px;
            }
            
            .info-value {
                font-size: 16px;
                font-weight: 600;
                color: #1f2937;
            }
            
            .amount-box {
                grid-column: 1 / -1;
                background-color: #ecfdf5;
                border: 2px solid #10B981;
                padding: 20px;
                border-radius: 6px;
                text-align: center;
            }
            
            .amount-label {
                font-size: 12px;
                font-weight: 700;
                text-transform: uppercase;
                color: #059669;
                letter-spacing: 0.5px;
                margin-bottom: 8px;
            }
            
            .amount-value {
                font-size: 32px;
                font-weight: 700;
                color: #10B981;
            }
            
            .footer {
                text-align: center;
                border-top: 1px solid #e5e7eb;
                padding-top: 15px;
                margin-top: 20px;
                font-size: 12px;
                color: #6b7280;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <!-- Warning -->
            <div class="warning-banner">
                <div class="warning-title">⚠️ Payment Due Soon</div>
                <div class="warning-text">Your payment for invoice #$invoiceNumber is due on $formattedDueDate</div>
            </div>
            
            <!-- Header -->
            <div class="header">
                <div class="business-name">$businessName</div>
                <p style="font-size: 13px; color: #6b7280;">Payment Reminder</p>
            </div>
            
            <!-- Details -->
            <div class="info-grid">
                <div class="info-box">
                    <div class="info-label">Invoice Number</div>
                    <div class="info-value">#$invoiceNumber</div>
                </div>
                
                <div class="info-box">
                    <div class="info-label">Customer</div>
                    <div class="info-value">$customerName</div>
                </div>
                
                <div class="amount-box">
                    <div class="amount-label">Amount Due</div>
                    <div class="amount-value">${currencyFormatter.format(amount)}</div>
                </div>
            </div>
            
            <!-- Footer -->
            <div class="footer">
                <p>Please arrange payment at your earliest convenience.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  static String generateOwnerSalesAlertEmailHtml({
    required String businessName,
    required String saleReference,
    required DateTime saleTime,
    required String customerName,
    String? customerEmail,
    String? customerPhone,
    String? cashierName,
    String? cashierEmail,
    String? storeName,
    String? cartLabel,
    required String paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required List<Map<String, dynamic>> items,
  }) {
    final timestamp = _formatDateTime(saleTime);
    final currency = NumberFormat.currency(symbol: 'NGN ', decimalDigits: 2);
    final totalQuantity = items.fold<double>(0.0, (sum, item) {
      final qty = item['quantity'];
      if (qty is num) return sum + qty.toDouble();
      return sum + (double.tryParse(qty?.toString() ?? '') ?? 0.0);
    });

    final itemRows = items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      final quantity = _readNum(item['quantity']);
      final unitPrice = _readNum(
        item['price'] ?? item['unitPrice'] ?? item['purchaseUnitCost'],
      );
      final lineTotal = _readNum(item['total']);
      final resolvedLineTotal =
          lineTotal > 0 ? lineTotal : (quantity * unitPrice);
      final unitLabel = (item['saleUnit'] ?? item['unit'] ?? '').toString();
      final pricingMode = (item['pricingMode'] ?? '').toString();
      final meta = <String>[
        if (unitLabel.trim().isNotEmpty) 'Unit: $unitLabel',
        if (pricingMode.trim().isNotEmpty)
          'Mode: ${_labelizeKey(pricingMode)}',
      ].join(' | ');
      return '''
      <tr>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#0f172a;">
          <div style="font-weight:700;">${index.toString().padLeft(2, '0')}. ${item['name'] ?? item['productName'] ?? 'Item'}</div>
          ${meta.isNotEmpty ? '<div style="margin-top:4px;color:#64748b;font-size:11px;">$meta</div>' : ''}
        </td>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;text-align:center;">${_formatCompactNumber(quantity)}</td>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;text-align:right;">${currency.format(unitPrice)}</td>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#0f172a;text-align:right;font-weight:700;">${currency.format(resolvedLineTotal)}</td>
      </tr>
      ''';
    }).join();

    final paymentRows = (paymentBreakdown ?? const <Map<String, dynamic>>[])
        .map((payment) {
      final amount = _readNum(payment['amount']);
      final method = (payment['method'] ?? paymentMethod).toString();
      final transactionId = (payment['transactionId'] ?? '').toString().trim();
      return '''
      <div style="display:flex;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid #e2e8f0;">
        <div>
          <div style="font-size:13px;font-weight:700;color:#0f172a;">${_labelizeKey(method)}</div>
          ${transactionId.isNotEmpty ? '<div style="font-size:11px;color:#64748b;">Txn: $transactionId</div>' : ''}
        </div>
        <div style="font-size:13px;font-weight:700;color:#0f172a;">${currency.format(amount)}</div>
      </div>
      ''';
    }).join();

    final summaryCards = <Map<String, String>>[
      {
        'label': 'Sale Total',
        'value': currency.format(total),
      },
      {
        'label': 'Items',
        'value': items.length.toString(),
      },
      {
        'label': 'Units',
        'value': _formatCompactNumber(totalQuantity),
      },
      {
        'label': 'Payment',
        'value': _labelizeKey(paymentMethod),
      },
    ];

    final summaryCardsHtml = summaryCards
        .map(
          (card) => '''
          <div class="metric-card">
            <div class="metric-label">${card['label']}</div>
            <div class="metric-value">${card['value']}</div>
          </div>
          ''',
        )
        .join();

    final timelineRows = <Map<String, String>>[
      {'label': 'Sale Reference', 'value': saleReference},
      {'label': 'Recorded At', 'value': timestamp},
      {'label': 'Customer', 'value': customerName},
      if ((customerEmail ?? '').trim().isNotEmpty)
        {'label': 'Customer Email', 'value': customerEmail!.trim()},
      if ((customerPhone ?? '').trim().isNotEmpty)
        {'label': 'Customer Phone', 'value': customerPhone!.trim()},
      if ((cashierName ?? '').trim().isNotEmpty)
        {'label': 'Cashier', 'value': cashierName!.trim()},
      if ((cashierEmail ?? '').trim().isNotEmpty)
        {'label': 'Cashier Email', 'value': cashierEmail!.trim()},
      if ((storeName ?? '').trim().isNotEmpty)
        {'label': 'Store', 'value': storeName!.trim()},
      if ((cartLabel ?? '').trim().isNotEmpty)
        {'label': 'Cart Session', 'value': cartLabel!.trim()},
    ];

    final timelineHtml = timelineRows
        .map(
          (row) => '''
          <div class="detail-row">
            <span class="detail-label">${row['label']}</span>
            <span class="detail-value">${row['value']}</span>
          </div>
          ''',
        )
        .join();

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Sale Alert - $businessName</title>
      <style>
        body {
          margin: 0;
          padding: 24px 12px;
          background: #eef4ff;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
          color: #14213d;
        }
        .shell {
          max-width: 720px;
          margin: 0 auto;
          background: #ffffff;
          border-radius: 24px;
          overflow: hidden;
          box-shadow: 0 24px 60px rgba(15, 23, 42, 0.12);
        }
        .hero {
          padding: 28px;
          background: linear-gradient(135deg, #0f4c81, #0f172a 78%);
          color: #ffffff;
        }
        .eyebrow {
          display: inline-block;
          padding: 7px 12px;
          border-radius: 999px;
          background: rgba(255, 255, 255, 0.14);
          font-size: 11px;
          font-weight: 800;
          letter-spacing: 0.1em;
          text-transform: uppercase;
        }
        .hero-title {
          margin: 18px 0 8px;
          font-size: 30px;
          line-height: 1.15;
          font-weight: 800;
        }
        .hero-copy {
          margin: 0;
          font-size: 15px;
          line-height: 1.75;
          color: rgba(255, 255, 255, 0.88);
        }
        .content {
          padding: 28px;
        }
        .metrics {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 14px;
          margin-top: -46px;
          margin-bottom: 24px;
        }
        .metric-card {
          padding: 18px;
          border-radius: 18px;
          background: #ffffff;
          border: 1px solid #dbe7ff;
          box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08);
        }
        .metric-label {
          font-size: 11px;
          font-weight: 800;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: #64748b;
          margin-bottom: 10px;
        }
        .metric-value {
          font-size: 22px;
          font-weight: 800;
          color: #0f172a;
        }
        .section-title {
          margin: 0 0 14px;
          font-size: 13px;
          font-weight: 800;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: #64748b;
        }
        .panel {
          border: 1px solid #e2e8f0;
          border-radius: 18px;
          padding: 18px;
          background: #ffffff;
        }
        .detail-row {
          display: flex;
          justify-content: space-between;
          gap: 16px;
          padding: 12px 0;
          border-bottom: 1px solid #e2e8f0;
        }
        .detail-row:last-child {
          border-bottom: 0;
        }
        .detail-label {
          font-size: 12px;
          color: #64748b;
        }
        .detail-value {
          font-size: 13px;
          font-weight: 700;
          color: #0f172a;
          text-align: right;
        }
        .items-table {
          width: 100%;
          border-collapse: collapse;
        }
        .items-table th {
          padding: 12px;
          background: #f8fbff;
          border-bottom: 1px solid #dbe7ff;
          font-size: 11px;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: #64748b;
        }
        .summary-box {
          margin-top: 18px;
          border-radius: 18px;
          background: linear-gradient(180deg, #f8fbff, #eef6ff);
          padding: 18px;
          border: 1px solid #dbe7ff;
        }
        .summary-line {
          display: flex;
          justify-content: space-between;
          gap: 16px;
          padding: 8px 0;
          font-size: 14px;
          color: #334155;
        }
        .summary-line.total {
          margin-top: 8px;
          padding-top: 14px;
          border-top: 1px solid #c9defc;
          font-size: 18px;
          font-weight: 800;
          color: #0f172a;
        }
        .footer {
          margin-top: 26px;
          padding-top: 18px;
          border-top: 1px solid #e2e8f0;
          text-align: center;
          font-size: 12px;
          color: #64748b;
          line-height: 1.8;
        }
        .credit {
          margin-top: 8px;
          font-weight: 700;
          color: #0f4c81;
        }
        @media only screen and (max-width: 540px) {
          .hero, .content {
            padding: 20px;
          }
          .metrics {
            grid-template-columns: 1fr;
            margin-top: 0;
          }
          .detail-row {
            flex-direction: column;
            align-items: flex-start;
          }
          .detail-value {
            text-align: left;
          }
        }
      </style>
    </head>
    <body>
      <div class="shell">
        <div class="hero">
          <div class="eyebrow">Owner Sale Alert</div>
          <h1 class="hero-title">A new sale has been recorded for $businessName</h1>
          <p class="hero-copy">This summary gives you the most important transaction context immediately: who purchased, who recorded it, how it was paid, what was sold, and the exact value of the transaction.</p>
        </div>
        <div class="content">
          <div class="metrics">
            $summaryCardsHtml
          </div>

          <div style="margin-bottom:24px;">
            <div class="section-title">Transaction Details</div>
            <div class="panel">
              $timelineHtml
            </div>
          </div>

          <div style="margin-bottom:24px;">
            <div class="section-title">Items Sold</div>
            <div class="panel" style="padding:0;overflow:hidden;">
              <table class="items-table">
                <thead>
                  <tr>
                    <th style="text-align:left;">Item</th>
                    <th style="text-align:center;">Qty</th>
                    <th style="text-align:right;">Unit Price</th>
                    <th style="text-align:right;">Line Total</th>
                  </tr>
                </thead>
                <tbody>
                  $itemRows
                </tbody>
              </table>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:1.2fr 0.8fr;gap:18px;">
            <div>
              <div class="section-title">Payment Breakdown</div>
              <div class="panel">
                ${paymentRows.isNotEmpty ? paymentRows : '<div style="font-size:14px;color:#334155;font-weight:700;">${_labelizeKey(paymentMethod)}</div>'}
              </div>
            </div>
            <div>
              <div class="section-title">Financial Summary</div>
              <div class="summary-box">
                <div class="summary-line">
                  <span>Subtotal</span>
                  <strong>${currency.format(subtotal)}</strong>
                </div>
                <div class="summary-line">
                  <span>Tax</span>
                  <strong>${currency.format(tax)}</strong>
                </div>
                <div class="summary-line">
                  <span>Discount</span>
                  <strong>${currency.format(discount)}</strong>
                </div>
                <div class="summary-line total">
                  <span>Total</span>
                  <strong>${currency.format(total)}</strong>
                </div>
              </div>
            </div>
          </div>

          <div class="footer">
            <div>This owner alert was generated automatically from the sales workflow.</div>
            <div>Keep this email for reconciliation, staff review, and customer follow-up when needed.</div>
            <div class="credit">Created by lbtech.site</div>
          </div>
        </div>
      </div>
    </body>
    </html>
    ''';
  }

  static String generateProcurementAlertEmailHtml({
    required String businessName,
    required String procurementId,
    required DateTime createdAt,
    required String createdByName,
    String? createdByEmail,
    String? supplierName,
    String? invoiceRef,
    String? storeName,
    String? referenceImageUrl,
    required int itemsCount,
    required double totalCost,
    required double totalQuantity,
    required List<Map<String, dynamic>> items,
  }) {
    final currency = NumberFormat.currency(symbol: 'NGN ', decimalDigits: 2);
    final createdAtText = _formatDateTime(createdAt);
    final itemRows = items.asMap().entries.map((entry) {
      final item = entry.value;
      final quantity = _readNum(item['purchaseQuantity'] ?? item['quantity']);
      final unitCost =
          _readNum(item['purchaseUnitCost'] ?? item['cost'] ?? item['price']);
      final total =
          _readNum(item['purchaseTotal'] ?? item['total']) > 0
              ? _readNum(item['purchaseTotal'] ?? item['total'])
              : quantity * unitCost;
      final purchaseUnit =
          (item['purchaseUnit'] ?? item['unit'] ?? '').toString().trim();
      final batchLabel = (item['batchLabel'] ?? '').toString().trim();
      final expiry = _coerceDateTime(item['expiryDate']);
      final metaBits = <String>[
        if (purchaseUnit.isNotEmpty) 'Unit: $purchaseUnit',
        if (batchLabel.isNotEmpty) 'Batch: $batchLabel',
        if (expiry != null) 'Expiry: ${_formatShortDate(expiry)}',
      ];
      return '''
      <tr>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#0f172a;">
          <div style="font-weight:700;">${item['name'] ?? 'Item'}</div>
          ${metaBits.isNotEmpty ? '<div style="margin-top:4px;font-size:11px;color:#64748b;">${metaBits.join(' | ')}</div>' : ''}
        </td>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;text-align:center;">${_formatCompactNumber(quantity)}</td>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;text-align:right;">${currency.format(unitCost)}</td>
        <td style="padding:14px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#0f172a;text-align:right;font-weight:700;">${currency.format(total)}</td>
      </tr>
      ''';
    }).join();

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Procurement Alert - $businessName</title>
      <style>
        body {
          margin: 0;
          padding: 24px 12px;
          background: #f6f7fb;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
          color: #111827;
        }
        .shell {
          max-width: 720px;
          margin: 0 auto;
          background: #ffffff;
          border-radius: 24px;
          overflow: hidden;
          box-shadow: 0 24px 60px rgba(15, 23, 42, 0.10);
        }
        .hero {
          padding: 28px;
          background: linear-gradient(135deg, #0b6e4f, #123524 78%);
          color: #ffffff;
        }
        .eyebrow {
          display: inline-block;
          padding: 7px 12px;
          border-radius: 999px;
          background: rgba(255, 255, 255, 0.14);
          font-size: 11px;
          font-weight: 800;
          letter-spacing: 0.1em;
          text-transform: uppercase;
        }
        .hero-title {
          margin: 18px 0 8px;
          font-size: 30px;
          line-height: 1.15;
          font-weight: 800;
        }
        .hero-copy {
          margin: 0;
          font-size: 15px;
          line-height: 1.75;
          color: rgba(255, 255, 255, 0.88);
        }
        .content {
          padding: 28px;
        }
        .metrics {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 14px;
          margin-top: -44px;
          margin-bottom: 24px;
        }
        .metric-card {
          padding: 18px;
          border-radius: 18px;
          background: #ffffff;
          border: 1px solid #d9efe6;
          box-shadow: 0 10px 30px rgba(15, 23, 42, 0.06);
        }
        .metric-label {
          font-size: 11px;
          font-weight: 800;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: #64748b;
          margin-bottom: 10px;
        }
        .metric-value {
          font-size: 21px;
          font-weight: 800;
          color: #0f172a;
        }
        .section-title {
          margin: 0 0 14px;
          font-size: 13px;
          font-weight: 800;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: #64748b;
        }
        .panel {
          border: 1px solid #e2e8f0;
          border-radius: 18px;
          padding: 18px;
          background: #ffffff;
        }
        .detail-row {
          display: flex;
          justify-content: space-between;
          gap: 16px;
          padding: 12px 0;
          border-bottom: 1px solid #e2e8f0;
        }
        .detail-row:last-child {
          border-bottom: 0;
        }
        .detail-label {
          font-size: 12px;
          color: #64748b;
        }
        .detail-value {
          font-size: 13px;
          font-weight: 700;
          color: #0f172a;
          text-align: right;
        }
        .items-table {
          width: 100%;
          border-collapse: collapse;
        }
        .items-table th {
          padding: 12px;
          background: #f7fcfa;
          border-bottom: 1px solid #d9efe6;
          font-size: 11px;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: #64748b;
        }
        .cta {
          display: inline-block;
          margin-top: 18px;
          padding: 13px 18px;
          border-radius: 12px;
          background: #0b6e4f;
          color: #ffffff !important;
          text-decoration: none;
          font-size: 14px;
          font-weight: 700;
        }
        .footer {
          margin-top: 26px;
          padding-top: 18px;
          border-top: 1px solid #e2e8f0;
          text-align: center;
          font-size: 12px;
          color: #64748b;
          line-height: 1.8;
        }
        .credit {
          margin-top: 8px;
          font-weight: 700;
          color: #0b6e4f;
        }
        @media only screen and (max-width: 600px) {
          .hero, .content {
            padding: 20px;
          }
          .metrics {
            grid-template-columns: 1fr;
            margin-top: 0;
          }
          .detail-row {
            flex-direction: column;
            align-items: flex-start;
          }
          .detail-value {
            text-align: left;
          }
        }
      </style>
    </head>
    <body>
      <div class="shell">
        <div class="hero">
          <div class="eyebrow">Procurement Entry Recorded</div>
          <h1 class="hero-title">$businessName has logged a new procurement</h1>
          <p class="hero-copy">This summary helps you review the stock replenishment immediately: supplier, invoice, quantities, total spend, and the exact items that were added into inventory.</p>
        </div>
        <div class="content">
          <div class="metrics">
            <div class="metric-card">
              <div class="metric-label">Procurement Total</div>
              <div class="metric-value">${currency.format(totalCost)}</div>
            </div>
            <div class="metric-card">
              <div class="metric-label">Items Count</div>
              <div class="metric-value">$itemsCount</div>
            </div>
            <div class="metric-card">
              <div class="metric-label">Units Added</div>
              <div class="metric-value">${_formatCompactNumber(totalQuantity)}</div>
            </div>
          </div>

          <div style="margin-bottom:24px;">
            <div class="section-title">Procurement Details</div>
            <div class="panel">
              <div class="detail-row">
                <span class="detail-label">Procurement ID</span>
                <span class="detail-value">$procurementId</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">Recorded At</span>
                <span class="detail-value">$createdAtText</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">Created By</span>
                <span class="detail-value">$createdByName</span>
              </div>
              ${((createdByEmail ?? '').trim().isNotEmpty) ? '<div class="detail-row"><span class="detail-label">Creator Email</span><span class="detail-value">${createdByEmail!.trim()}</span></div>' : ''}
              ${((supplierName ?? '').trim().isNotEmpty) ? '<div class="detail-row"><span class="detail-label">Supplier</span><span class="detail-value">${supplierName!.trim()}</span></div>' : ''}
              ${((invoiceRef ?? '').trim().isNotEmpty) ? '<div class="detail-row"><span class="detail-label">Invoice / Reference</span><span class="detail-value">${invoiceRef!.trim()}</span></div>' : ''}
              ${((storeName ?? '').trim().isNotEmpty) ? '<div class="detail-row"><span class="detail-label">Store</span><span class="detail-value">${storeName!.trim()}</span></div>' : ''}
            </div>
            ${((referenceImageUrl ?? '').trim().isNotEmpty) ? '<a class="cta" href="${referenceImageUrl!.trim()}">Open Reference Attachment</a>' : ''}
          </div>

          <div>
            <div class="section-title">Procured Items</div>
            <div class="panel" style="padding:0;overflow:hidden;">
              <table class="items-table">
                <thead>
                  <tr>
                    <th style="text-align:left;">Item</th>
                    <th style="text-align:center;">Qty</th>
                    <th style="text-align:right;">Unit Cost</th>
                    <th style="text-align:right;">Line Total</th>
                  </tr>
                </thead>
                <tbody>
                  $itemRows
                </tbody>
              </table>
            </div>
          </div>

          <div class="footer">
            <div>This procurement alert was generated automatically after inventory replenishment was saved.</div>
            <div>Use this message for audit, supplier follow-up, and stock control review.</div>
            <div class="credit">Created by lbtech.site</div>
          </div>
        </div>
      </div>
    </body>
    </html>
    ''';
  }

  static String generateAdminBroadcastEmailHtml({
    required String subject,
    required String body,
    required DateTime sentAt,
    String? senderLabel,
  }) {
    final paragraphs = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => '<p style="margin:0 0 14px;font-size:15px;line-height:1.8;color:#334155;">$line</p>')
        .join();

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>$subject</title>
      <style>
        body {
          margin: 0;
          padding: 24px 12px;
          background: #f3f6fb;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
          color: #0f172a;
        }
        .shell {
          max-width: 680px;
          margin: 0 auto;
          background: #ffffff;
          border-radius: 24px;
          overflow: hidden;
          box-shadow: 0 24px 60px rgba(15, 23, 42, 0.10);
        }
        .hero {
          padding: 28px;
          background: linear-gradient(135deg, #6d28d9, #1f2937 80%);
          color: #ffffff;
        }
        .eyebrow {
          display: inline-block;
          padding: 7px 12px;
          border-radius: 999px;
          background: rgba(255, 255, 255, 0.14);
          font-size: 11px;
          font-weight: 800;
          letter-spacing: 0.1em;
          text-transform: uppercase;
        }
        .hero-title {
          margin: 18px 0 8px;
          font-size: 30px;
          line-height: 1.15;
          font-weight: 800;
        }
        .hero-copy {
          margin: 0;
          font-size: 15px;
          line-height: 1.75;
          color: rgba(255, 255, 255, 0.88);
        }
        .content {
          padding: 28px;
        }
        .meta-card {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 14px;
          margin-top: -42px;
          margin-bottom: 24px;
        }
        .meta-box {
          padding: 18px;
          border-radius: 18px;
          background: #ffffff;
          border: 1px solid #e6dcff;
          box-shadow: 0 10px 30px rgba(15, 23, 42, 0.06);
        }
        .meta-label {
          font-size: 11px;
          font-weight: 800;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: #64748b;
          margin-bottom: 10px;
        }
        .meta-value {
          font-size: 18px;
          font-weight: 800;
          color: #0f172a;
        }
        .message-card {
          border: 1px solid #e2e8f0;
          border-radius: 18px;
          padding: 22px;
          background: #ffffff;
        }
        .section-title {
          margin: 0 0 14px;
          font-size: 13px;
          font-weight: 800;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: #64748b;
        }
        .footer {
          margin-top: 26px;
          padding-top: 18px;
          border-top: 1px solid #e2e8f0;
          text-align: center;
          font-size: 12px;
          color: #64748b;
          line-height: 1.8;
        }
        .credit {
          margin-top: 8px;
          font-weight: 700;
          color: #6d28d9;
        }
        @media only screen and (max-width: 540px) {
          .hero, .content {
            padding: 20px;
          }
          .meta-card {
            grid-template-columns: 1fr;
            margin-top: 0;
          }
        }
      </style>
    </head>
    <body>
      <div class="shell">
        <div class="hero">
          <div class="eyebrow">Admin Communication</div>
          <h1 class="hero-title">$subject</h1>
          <p class="hero-copy">This message was sent from the platform administration center so you can stay informed about important business or account updates.</p>
        </div>
        <div class="content">
          <div class="meta-card">
            <div class="meta-box">
              <div class="meta-label">Sent At</div>
              <div class="meta-value">${_formatDateTime(sentAt)}</div>
            </div>
            <div class="meta-box">
              <div class="meta-label">Sent By</div>
              <div class="meta-value">${(senderLabel ?? 'Platform Admin').trim().isEmpty ? 'Platform Admin' : senderLabel!.trim()}</div>
            </div>
          </div>

          <div class="section-title">Message</div>
          <div class="message-card">
            $paragraphs
          </div>

          <div class="footer">
            <div>Please do not ignore this message if it relates to your account, billing, or operations.</div>
            <div>Keep this email for reference whenever you need support follow-up.</div>
            <div class="credit">Created by lbtech.site</div>
          </div>
        </div>
      </div>
    </body>
    </html>
    ''';
  }

  static String generateWorkerInvitationEmailHtml({
    required String businessName,
    required String workerName,
    required String role,
    required String email,
    required String temporaryPassword,
  }) {
    return _renderActionEmail(
      title: 'Worker Invitation',
      eyebrow: 'Team Access',
      headline: 'You have been invited to join $businessName',
      intro:
          'Your workspace is ready. Use the credentials below to sign in and update your password after your first login.',
      accentColor: '#7C3AED',
      infoRows: {
        'Business': businessName,
        'Name': workerName,
        'Role': role,
        'Login Email': email,
        'Temporary Password': temporaryPassword,
      },
      highlights: const [
        'Sign in with the email and temporary password above.',
        'Change your password after your first login.',
        'Contact the business owner if you need help accessing your workspace.',
      ],
      footerNote: 'This invitation was sent automatically from Manage Care.',
    );
  }

  static String generateSubscriptionStatusEmailHtml({
    required String businessName,
    required String recipientName,
    required String planName,
    required double amount,
    required String statusLabel,
    required String statusMessage,
    String? requestId,
    String? businessType,
    DateTime? startsOn,
    DateTime? endsOn,
    String? actionLabel,
    String? actionUrl,
  }) {
    final normalizedStatus = statusLabel.toLowerCase();
    final accentColor = normalizedStatus.contains('pending')
        ? '#D97706'
        : normalizedStatus.contains('cancel')
            ? '#DC2626'
            : '#059669';

    return _renderActionEmail(
      title: 'Subscription Update',
      eyebrow: 'Subscription',
      headline: 'Hello $recipientName, your subscription has been updated',
      intro: statusMessage,
      accentColor: accentColor,
      infoRows: {
        'Business': businessName,
        if ((businessType ?? '').trim().isNotEmpty) 'Business Type': businessType!,
        'Plan': planName,
        'Amount': _formatMoney(amount),
        'Status': statusLabel,
        if ((requestId ?? '').trim().isNotEmpty) 'Reference': requestId!,
        if (startsOn != null) 'Start Date': _formatShortDate(startsOn),
        if (endsOn != null) 'End Date': _formatShortDate(endsOn),
      },
      highlights: const [
        'You can continue managing your business from the app.',
        'Keep your payment proof and reference details for support follow-up.',
      ],
      actionLabel: actionLabel,
      actionUrl: actionUrl,
      footerNote: 'Manage Care will continue to notify you about important subscription changes.',
    );
  }

  static String generateTenantWelcomeEmailHtml({
    required String businessName,
    required String tenantName,
    String? propertyTitle,
    String? contactEmail,
    String? contactPhone,
    String? whatsapp,
  }) {
    return _renderActionEmail(
      title: 'Tenant Welcome',
      eyebrow: 'Real Estate',
      headline: 'Welcome to $businessName',
      intro:
          'Your tenant profile has been created successfully. We will use this contact information for lease updates, rent reminders, and payment receipts.',
      accentColor: '#0369A1',
      infoRows: {
        'Tenant': tenantName,
        'Business': businessName,
        if ((propertyTitle ?? '').trim().isNotEmpty) 'Property': propertyTitle!,
        if ((contactEmail ?? '').trim().isNotEmpty) 'Support Email': contactEmail!,
        if ((contactPhone ?? '').trim().isNotEmpty) 'Support Phone': contactPhone!,
        if ((whatsapp ?? '').trim().isNotEmpty) 'WhatsApp': whatsapp!,
      },
      highlights: const [
        'Watch your email for lease updates and payment confirmations.',
        'Keep your phone number active so you do not miss rent reminders.',
      ],
      footerNote: 'Thank you for choosing Manage Care for your property operations.',
    );
  }

  static String generateLeaseCreatedEmailHtml({
    required String businessName,
    required String tenantName,
    required String propertyTitle,
    required String leaseType,
    required DateTime startDate,
    required DateTime endDate,
    required double monthlyRent,
    required double deposit,
    String? contactEmail,
    String? contactPhone,
  }) {
    return _renderActionEmail(
      title: 'Lease Created',
      eyebrow: 'Lease Details',
      headline: 'Your lease for $propertyTitle has been created',
      intro:
          'Please review the details below and reach out if anything needs to be corrected before move-in or renewal planning.',
      accentColor: '#0F766E',
      infoRows: {
        'Tenant': tenantName,
        'Business': businessName,
        'Property': propertyTitle,
        'Lease Type': _labelizeKey(leaseType),
        'Start Date': _formatShortDate(startDate),
        'End Date': _formatShortDate(endDate),
        'Rent': _formatMoney(monthlyRent),
        'Deposit': _formatMoney(deposit),
        if ((contactEmail ?? '').trim().isNotEmpty) 'Contact Email': contactEmail!,
        if ((contactPhone ?? '').trim().isNotEmpty) 'Contact Phone': contactPhone!,
      },
      highlights: const [
        'Store this email with your tenancy records.',
        'Rent reminders and receipts will use the tenant contact details on file.',
      ],
      footerNote: 'Generated automatically by Manage Care real-estate tools.',
    );
  }

  static String generateRentReceiptEmailHtml({
    required String businessName,
    required String tenantName,
    required String propertyTitle,
    required double amount,
    required String paymentMethod,
    required DateTime paidDate,
    int durationMonths = 1,
    DateTime? nextDueDate,
    String? receiptUrl,
  }) {
    return _renderActionEmail(
      title: 'Rent Payment Receipt',
      eyebrow: 'Payment Confirmed',
      headline: 'Your rent payment has been recorded successfully',
      intro:
          'This email confirms that your payment has been received and saved in the business records.',
      accentColor: '#059669',
      infoRows: {
        'Tenant': tenantName,
        'Business': businessName,
        'Property': propertyTitle,
        'Amount Paid': _formatMoney(amount),
        'Payment Method': paymentMethod,
        'Paid On': _formatDateTime(paidDate),
        'Coverage': '$durationMonths month${durationMonths == 1 ? '' : 's'}',
        if (nextDueDate != null) 'Next Due Date': _formatShortDate(nextDueDate),
      },
      highlights: const [
        'Keep this payment confirmation for your records.',
        'Contact the property manager if you need the uploaded receipt file re-shared.',
      ],
      actionLabel:
          (receiptUrl ?? '').trim().isNotEmpty ? 'Open Uploaded Receipt' : null,
      actionUrl: receiptUrl,
      footerNote: 'Thank you for staying current with your rent payments.',
    );
  }

  static String _renderActionEmail({
    required String title,
    required String eyebrow,
    required String headline,
    required String intro,
    required String accentColor,
    required Map<String, String> infoRows,
    List<String> highlights = const [],
    String? actionLabel,
    String? actionUrl,
    String? footerNote,
  }) {
    final infoHtml = infoRows.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map(
          (entry) => '''
            <div class="info-row">
              <span class="info-label">${entry.key}</span>
              <span class="info-value">${entry.value}</span>
            </div>
          ''',
        )
        .join();

    final highlightsHtml = highlights
        .where((item) => item.trim().isNotEmpty)
        .map((item) => '<li>$item</li>')
        .join();

    final actionHtml = (actionLabel ?? '').trim().isNotEmpty &&
            (actionUrl ?? '').trim().isNotEmpty
        ? '''
          <div class="action-wrap">
            <a class="action-button" href="$actionUrl">$actionLabel</a>
          </div>
        '''
        : '';

    final footerHtml = (footerNote ?? '').trim().isNotEmpty
        ? '<div class="footer-note">$footerNote</div>'
        : '';

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>$title</title>
      <style>
        body {
          margin: 0;
          padding: 24px 12px;
          background: #f4f7fb;
          color: #172033;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
        }
        .shell {
          max-width: 640px;
          margin: 0 auto;
          background: #ffffff;
          border-radius: 18px;
          overflow: hidden;
          box-shadow: 0 20px 45px rgba(15, 23, 42, 0.10);
        }
        .hero {
          padding: 28px 28px 20px;
          background: linear-gradient(135deg, $accentColor, #0f172a);
          color: #ffffff;
        }
        .eyebrow {
          display: inline-block;
          margin-bottom: 12px;
          padding: 6px 10px;
          border-radius: 999px;
          background: rgba(255, 255, 255, 0.16);
          font-size: 11px;
          font-weight: 700;
          letter-spacing: 0.10em;
          text-transform: uppercase;
        }
        .headline {
          margin: 0;
          font-size: 26px;
          line-height: 1.2;
          font-weight: 800;
        }
        .intro {
          margin: 14px 0 0;
          font-size: 15px;
          line-height: 1.7;
          color: rgba(255, 255, 255, 0.88);
        }
        .content {
          padding: 28px;
        }
        .section-title {
          margin: 0 0 14px;
          font-size: 13px;
          font-weight: 800;
          color: #667085;
          letter-spacing: 0.08em;
          text-transform: uppercase;
        }
        .info-card {
          border: 1px solid #e2e8f0;
          border-radius: 14px;
          overflow: hidden;
          background: #ffffff;
        }
        .info-row {
          display: flex;
          justify-content: space-between;
          gap: 16px;
          padding: 14px 16px;
          border-bottom: 1px solid #e2e8f0;
        }
        .info-row:last-child {
          border-bottom: 0;
        }
        .info-label {
          color: #64748b;
          font-size: 13px;
        }
        .info-value {
          color: #0f172a;
          font-size: 13px;
          font-weight: 700;
          text-align: right;
        }
        .highlights {
          margin: 22px 0 0;
          padding: 18px 20px 18px 38px;
          border-radius: 14px;
          background: #f8fafc;
        }
        .highlights li {
          margin-bottom: 10px;
          color: #334155;
          font-size: 14px;
          line-height: 1.6;
        }
        .highlights li:last-child {
          margin-bottom: 0;
        }
        .action-wrap {
          margin-top: 24px;
        }
        .action-button {
          display: inline-block;
          padding: 13px 18px;
          border-radius: 12px;
          background: $accentColor;
          color: #ffffff !important;
          text-decoration: none;
          font-size: 14px;
          font-weight: 700;
        }
        .footer-note {
          margin-top: 24px;
          color: #64748b;
          font-size: 13px;
          line-height: 1.6;
        }
        @media only screen and (max-width: 520px) {
          .hero, .content {
            padding: 22px 18px;
          }
          .headline {
            font-size: 22px;
          }
          .info-row {
            flex-direction: column;
            align-items: flex-start;
          }
          .info-value {
            text-align: left;
          }
        }
      </style>
    </head>
    <body>
      <div class="shell">
        <div class="hero">
          <div class="eyebrow">$eyebrow</div>
          <h1 class="headline">$headline</h1>
          <p class="intro">$intro</p>
        </div>
        <div class="content">
          <div class="section-title">$title</div>
          <div class="info-card">
            $infoHtml
          </div>
          ${highlightsHtml.isNotEmpty ? '<ul class="highlights">$highlightsHtml</ul>' : ''}
          $actionHtml
          $footerHtml
        </div>
      </div>
    </body>
    </html>
    ''';
  }

  static String _formatMoney(double amount) {
    return NumberFormat.currency(symbol: 'NGN ', decimalDigits: 2)
        .format(amount);
  }

  static String _formatShortDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String _formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }

  static double _readNum(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static String _formatCompactNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  static DateTime? _coerceDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final timestampDate = _timestampToDateTime(value);
    if (timestampDate != null) return timestampDate;
    return DateTime.tryParse(value.toString());
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    try {
      final dynamic seconds = value.seconds;
      if (seconds is int) {
        final dynamic nanoseconds = value.nanoseconds;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + ((nanoseconds is int ? nanoseconds : 0) ~/ 1000000),
        );
      }
    } catch (_) {}
    return null;
  }

  static String _labelizeKey(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((segment) => segment.trim().isNotEmpty)
        .map(
          (segment) => segment.substring(0, 1).toUpperCase() +
              segment.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

