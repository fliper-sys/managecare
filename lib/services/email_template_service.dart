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
}

