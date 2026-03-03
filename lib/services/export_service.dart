
import '../core/utils/datetime_utils.dart';
import 'package:intl/intl.dart';

import '../data/models/sale_model.dart';

/// Service for exporting sales and order history in multiple formats
class ExportService {
  static const String _dateFormat = 'yyyy-MM-dd HH:mm:ss';
  static final DateFormat _dateFormatter = DateFormat(_dateFormat);

  /// Export sales to CSV format
  static Future<String> exportToCSV(List<SaleModel> sales) async {
    try {
      final StringBuffer buffer = StringBuffer();

      // Add header
      buffer.writeln([
        'Order ID',
        'Receipt #',
        'Date',
        'Customer',
        'Items',
        'Quantity',
        'Unit Price',
        'Total',
        'Payment Method',
        'Status',
      ].join(','));

      // Add sales data
      for (final sale in sales) {
        for (int i = 0; i < sale.items.length; i++) {
          final item = sale.items[i];
          buffer.writeln([
            sale.id,
            sale.receiptNumber ?? 'N/A',
            _dateFormatter.format(sale.createdAt),
            sale.customerName ?? 'N/A',
            item.productName,
            item.quantity,
            item.unitPrice,
            item.total,
            sale.paymentMethod,
            sale.status,
          ].join(','));
        }

        // If no items, add summary row
        if (sale.items.isEmpty) {
          buffer.writeln([
            sale.id,
            sale.receiptNumber ?? 'N/A',
            _dateFormatter.format(sale.createdAt),
            sale.customerName ?? 'N/A',
            'N/A',
            0,
            0,
            sale.totalAmount,
            sale.paymentMethod,
            sale.status,
          ].join(','));
        }
      }

      return buffer.toString();
    } catch (e) {
      throw Exception('Failed to export to CSV: $e');
    }
  }

  /// Export sales to JSON format
  static Future<String> exportToJSON(List<SaleModel> sales) async {
    try {
      final List<Map<String, dynamic>> jsonData = [];

      for (final sale in sales) {
        jsonData.add({
          'id': sale.id,
          'receiptNumber': sale.receiptNumber,
          'businessId': sale.businessId,
          'customerId': sale.customerId,
          'customerName': sale.customerName,
          'createdAt': sale.createdAt.toIso8601String(),
          'updatedAt': sale.updatedAt?.toIso8601String(),
          'items': sale.items
              .map((item) => {
                    'productName': item.productName,
                    'id': item.id,
                    'quantity': item.quantity,
                    'unitPrice': item.unitPrice,
                    'total': item.total,
                  })
              .toList(),
          'totalAmount': sale.totalAmount,
          'taxAmount': sale.taxAmount,
          'discountAmount': sale.discountAmount,
          'finalAmount': sale.finalAmount,
          'paymentMethod': sale.paymentMethod,
          'notes': sale.notes,
          'status': sale.status,
        });
      }

      // Convert to JSON string with proper formatting
      return _formatJson(jsonData);
    } catch (e) {
      throw Exception('Failed to export to JSON: $e');
    }
  }

  /// Format JSON with proper indentation
  static String _formatJson(List<Map<String, dynamic>> data) {
    StringBuffer sb = StringBuffer();
    sb.write('[\n');
    for (int i = 0; i < data.length; i++) {
      sb.write('  ');
      sb.write(_jsonEncode(data[i], 1));
      if (i < data.length - 1) sb.write(',');
      sb.write('\n');
    }
    sb.write(']');
    return sb.toString();
  }

  /// Recursive JSON encoder with indentation
  static String _jsonEncode(dynamic obj, int indent) {
    String pad = '  ' * indent;
    String nextPad = '  ' * (indent + 1);

    if (obj == null) return 'null';
    if (obj is bool) return obj.toString();
    if (obj is num) return obj.toString();
    if (obj is String) return '"${obj.replaceAll('"', '\\"')}"';

    if (obj is List) {
      if (obj.isEmpty) return '[]';
      StringBuffer sb = StringBuffer('[\n');
      for (int i = 0; i < obj.length; i++) {
        sb.write(nextPad);
        sb.write(_jsonEncode(obj[i], indent + 1));
        if (i < obj.length - 1) sb.write(',');
        sb.write('\n');
      }
      sb.write('$pad]');
      return sb.toString();
    }

    if (obj is Map) {
      if (obj.isEmpty) return '{}';
      StringBuffer sb = StringBuffer('{\n');
      List<String> keys = obj.keys.cast<String>().toList();
      for (int i = 0; i < keys.length; i++) {
        sb.write(nextPad);
        sb.write('"${keys[i]}": ');
        sb.write(_jsonEncode(obj[keys[i]], indent + 1));
        if (i < keys.length - 1) sb.write(',');
        sb.write('\n');
      }
      sb.write('$pad}');
      return sb.toString();
    }

    return obj.toString();
  }

  /// Export sales to TSV (Tab-Separated Values) format
  static Future<String> exportToTSV(List<SaleModel> sales) async {
    try {
      final StringBuffer buffer = StringBuffer();

      // Add header
      buffer.writeln([
        'Order ID',
        'Receipt #',
        'Date',
        'Customer',
        'Items',
        'Quantity',
        'Unit Price',
        'Total',
        'Payment Method',
        'Status',
      ].join('\t'));

      // Add sales data
      for (final sale in sales) {
        for (int i = 0; i < sale.items.length; i++) {
          final item = sale.items[i];
          buffer.writeln([
            sale.id,
            sale.receiptNumber ?? 'N/A',
            _dateFormatter.format(sale.createdAt),
            sale.customerName ?? 'N/A',
            item.productName,
            item.quantity,
            item.unitPrice,
            item.total,
            sale.paymentMethod,
            sale.status,
          ].join('\t'));
        }

        // If no items, add summary row
        if (sale.items.isEmpty) {
          buffer.writeln([
            sale.id,
            sale.receiptNumber ?? 'N/A',
            _dateFormatter.format(sale.createdAt),
            sale.customerName ?? 'N/A',
            'N/A',
            0,
            0,
            sale.totalAmount,
            sale.paymentMethod,
            sale.status,
          ].join('\t'));
        }
      }

      return buffer.toString();
    } catch (e) {
      throw Exception('Failed to export to TSV: $e');
    }
  }

  /// Generate summary report
  static Future<String> generateSummaryReport(List<SaleModel> sales) async {
    try {
      final StringBuffer report = StringBuffer();
      final DateFormat dateFormat = DateFormat('dd MMM yyyy HH:mm');

      // Calculate statistics
      int totalSales = sales.length;
      double totalAmount = 0;
      double totalTax = 0;
      double totalDiscount = 0;
      Map<String, int> paymentMethodCounts = {};
      Map<String, double> paymentMethodTotals = {};

      for (final sale in sales) {
        totalAmount += sale.totalAmount;
        totalTax += sale.taxAmount;
        totalDiscount += sale.discountAmount;

        final method = sale.paymentMethod;
        paymentMethodCounts[method] = (paymentMethodCounts[method] ?? 0) + 1;
        paymentMethodTotals[method] =
            (paymentMethodTotals[method] ?? 0) + sale.totalAmount;
      }

      // Generate report
      report.writeln('═' * 60);
      report.writeln('SALES SUMMARY REPORT');
      report.writeln('═' * 60);
      report.writeln('Generated: ${dateFormat.format(DateTime.now())}');
      report.writeln('');

      report.writeln('OVERVIEW');
      report.writeln('─' * 60);
      report.writeln('Total Transactions: $totalSales');
      report.writeln('Total Amount: ₦${totalAmount.toStringAsFixed(2)}');
      report.writeln('Total Tax: ₦${totalTax.toStringAsFixed(2)}');
      report.writeln('Total Discount: ₦${totalDiscount.toStringAsFixed(2)}');
      report.writeln(
          'Average Transaction: ₦${(totalAmount / (totalSales == 0 ? 1 : totalSales)).toStringAsFixed(2)}');
      report.writeln('');

      report.writeln('PAYMENT METHOD BREAKDOWN');
      report.writeln('─' * 60);
      for (final method in paymentMethodCounts.keys) {
        final count = paymentMethodCounts[method] ?? 0;
        final total = paymentMethodTotals[method] ?? 0;
        final percentage = totalAmount > 0 ? ((total / totalAmount) * 100) : 0;
        report.writeln(
            '$method: $count transactions | ₦${total.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)');
      }
      report.writeln('');

      report.writeln('DATE RANGE');
      report.writeln('─' * 60);
      if (sales.isNotEmpty) {
        final dates = sales.map((s) => s.createdAt).toList();
        if (dates.isNotEmpty) {
          dates.sort();
          report.writeln('From: ${dateFormat.format(dates.first)}');
          report.writeln('To: ${dateFormat.format(dates.last)}');
        }
      }
      report.writeln('');
      report.writeln('═' * 60);

      return report.toString();
    } catch (e) {
      throw Exception('Failed to generate summary report: $e');
    }
  }

  /// --- Raw exports: accept raw sales docs from ReportsProvider.fetchSalesList ---
  static Future<String> exportRawToCSV(List<Map<String, dynamic>> raw) async {
    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln([
        'Order ID',
        'Date',
        'Customer',
        'Items',
        'Quantity',
        'Unit Price',
        'Total',
        'Payment Method',
        'Status'
      ].join(','));

      for (final entry in raw) {
        final id = entry['id'] as String? ?? '';
        final data = entry['data'] as Map<String, dynamic>? ?? {};
        final created = data['createdAt'];
        final createdDt = parseTimestamp(created);
        final dateStr = _dateFormatter.format(createdDt);
        final customer = (data['customerName'] ?? data['customerDisplayName'] ?? data['customer'] ?? '').toString();
        final items = (data['items'] as List?) ?? [];
        if (items.isNotEmpty) {
          for (final it in items) {
            final item = it is Map ? it : {};
            final pname = (item['productName'] ?? item['name'] ?? '').toString();
            final qty = (item['quantity'] ?? item['qty'] ?? 0).toString();
            final unitPrice = (item['unitPrice'] ?? item['price'] ?? 0).toString();
            final total = (item['total'] ?? (item['quantity'] ?? 0) * (item['unitPrice'] ?? 0) ?? 0).toString();
            final pm = (data['paymentMethod'] ?? data['payment'] ?? '').toString();
            final status = (data['status'] ?? '').toString();
            buffer.writeln([id, dateStr, customer, pname, qty, unitPrice, total, pm, status].join(','));
          }
        } else {
          final total = ((data['finalAmount'] ?? data['totalAmount'] ?? data['total'] ?? 0) as num).toString();
          final pm = (data['paymentMethod'] ?? data['payment'] ?? '').toString();
          final status = (data['status'] ?? '').toString();
          buffer.writeln([id, dateStr, customer, 'N/A', '0', '0', total, pm, status].join(','));
        }
      }

      return buffer.toString();
    } catch (e) {
      throw Exception('Failed to export raw to CSV: $e');
    }
  }

  static Future<String> exportRawToJSON(List<Map<String, dynamic>> raw) async {
    try {
      final List<Map<String, dynamic>> out = [];
      for (final entry in raw) {
        final id = entry['id'] as String? ?? '';
        final data = Map<String, dynamic>.from(entry['data'] as Map<String, dynamic>? ?? {});
        data['id'] = id;
        out.add(data);
      }
      return _formatJson(out);
    } catch (e) {
      throw Exception('Failed to export raw to JSON: $e');
    }
  }



  static Future<String> generateSummaryFromRaw(List<Map<String, dynamic>> raw) async {
    try {
      // Map raw docs into a minimal structure to reuse existing summary generation logic
      final List<SaleModel> sales = raw.map((entry) {
        final id = entry['id'] as String? ?? '';
        final Map<String, dynamic> data = Map<String, dynamic>.from(entry['data'] as Map<String, dynamic>? ?? {});
        // Build SaleModel with best-effort mapping
        final items = (data['items'] as List?)?.map((it) {
          final m = it is Map ? it : {};
          return SaleItem(
            id: (m['id'] ?? '') as String,
            productId: (m['productId'] ?? '') as String,
            productName: (m['productName'] ?? m['name'] ?? '') as String,
            quantity: (m['quantity'] ?? m['qty'] ?? 0).toDouble(),
            unitPrice: ((m['unitPrice'] ?? m['price'] ?? 0) as num).toDouble(),
            discount: ((m['discount'] ?? 0) as num).toDouble(),
            total: ((m['total'] ?? 0) as num).toDouble(),
          );
        }).toList() ?? [];

        DateTime createdAt = parseTimestamp(data['createdAt']);

        return SaleModel(
          id: id,
          businessId: (data['businessId'] ?? '') as String,
          customerId: data['customerId'] as String?,
          customerName: data['customerName'] as String?,
          items: items.cast<SaleItem>(),
          totalAmount: ((data['totalAmount'] ?? data['total'] ?? 0) as num).toDouble(),
          discountAmount: ((data['discountAmount'] ?? data['discount'] ?? 0) as num).toDouble(),
          taxAmount: ((data['taxAmount'] ?? data['tax'] ?? 0) as num).toDouble(),
          finalAmount: ((data['finalAmount'] ?? data['totalAmount'] ?? data['total'] ?? 0) as num).toDouble(),
          paymentMethod: (data['paymentMethod'] ?? data['payment'] ?? 'unknown') as String,
          status: (data['status'] ?? 'completed') as String,
          receiptNumber: data['receiptNumber'] as String?,
          notes: data['notes'] as String?,
          createdBy: (data['createdBy'] ?? '') as String,
          createdAt: createdAt,
          updatedAt: parseTimestamp(data['updatedAt']),
        );
      }).toList();

      return await generateSummaryReport(sales);
    } catch (e) {
      throw Exception('Failed to generate summary from raw: $e');
    }
  }
  /// Get filename with timestamp
  static String getExportFilename(String format) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    switch (format.toLowerCase()) {
      case 'csv':
        return 'sales_export_$timestamp.csv';
      case 'json':
        return 'sales_export_$timestamp.json';
      case 'tsv':
        return 'sales_export_$timestamp.tsv';
      case 'txt':
        return 'sales_report_$timestamp.txt';
      default:
        return 'export_$timestamp.txt';
    }
  }

  /// Validate export data
  static bool validateExportData(List<SaleModel> sales) {
    if (sales.isEmpty) return false;

    // Check if at least one sale has required fields
    return sales.isNotEmpty;
  }
}

