import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'dart:convert';

/// ESC/POS Receipt Generator for thermal printers
/// Generates ESC/POS commands for thermal printer output
class EscPosReceiptGenerator {

  // ESC/POS Command bytes
  static const int ESC = 0x1B; // Escape
  static const int GS = 0x1D; // Group separator
  static const int LF = 0x0A; // Line feed
  static const int CR = 0x0D; // Carriage return

  // Paper widths (characters per line)
  static const int charsPer58mm = 30;
  static const int charsPer80mm = 48;

  /// Generate complete ESC/POS receipt
  static Uint8List generateReceipt({
    required String businessName,
    required String receiptNumber,
    required DateTime receiptDate,
    required List<ReceiptLineItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    String? customerName,
    String? storeName,
    String? storeAddress,
    String? storeTelephone,
    String? vatNumber,
    String? cashier,
    String? notes,
    String? invoiceUrl,
    String currencySymbol = '₦',
    int paperWidth = 58, // 58mm or 80mm
    bool showQrCode = false,
    String? copyLabel, // e.g. 'CUSTOMER COPY' or 'BUSINESS COPY'
  }) {
    final charsPerLine = paperWidth == 58 ? charsPer58mm : charsPer80mm;
    final buffer = EscPosBuffer(paperWidth);

    // Initialize printer
    buffer.initializePrinter();

    // Header - Formal style
    buffer.setAlignment(EscPosAlignment.center);
    buffer.printText(businessName.toUpperCase(), bold: true, fontSize: EscPosFontSize.large);

    // Optional copy label (e.g. "CUSTOMER COPY" or "BUSINESS COPY")
    if (copyLabel != null && copyLabel.isNotEmpty) {
      buffer.printText(copyLabel, bold: true);
    }

    if (storeName != null && storeName.isNotEmpty) {
      buffer.printText(storeName, bold: true);
    }
    if (storeAddress != null && storeAddress.isNotEmpty) {
      // Support multi-line address
      for (var line in storeAddress.split('\n')) {
        buffer.printText(line, fontSize: EscPosFontSize.small);
      }
    }
    if (storeTelephone != null && storeTelephone.isNotEmpty) {
      buffer.printText('Tel: $storeTelephone', fontSize: EscPosFontSize.small);
    }
    if (vatNumber != null && vatNumber.isNotEmpty) {
      buffer.printText('VAT: $vatNumber', fontSize: EscPosFontSize.small);
    }

    buffer.printLine();

    // Title
    buffer.setAlignment(EscPosAlignment.center);
    buffer.printText('TAX INVOICE', bold: true);

    // Receipt info
    buffer.setAlignment(EscPosAlignment.left);
    buffer.printText('Invoice #: $receiptNumber');
    buffer.printText('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(receiptDate)}');
    if (cashier != null && cashier.isNotEmpty) {
      buffer.printText('Cashier: $cashier');
    }
    if (customerName != null && customerName.isNotEmpty) {
      buffer.printText('Customer: $customerName');
    }

    buffer.printDashedLine();

    // Items header with dynamic widths
    final qtyWidth = 4;
    final unitWidth = 8;
    final totalWidth = 10;
    final nameWidth = charsPerLine - (qtyWidth + unitWidth + totalWidth);

    buffer.setAlignment(EscPosAlignment.left);
    buffer.printText(_padRight('Item', nameWidth) + _padLeft('Qty', qtyWidth) + _padLeft('Unit', unitWidth) + _padLeft('Total', totalWidth));
    buffer.printDashedLine();

    // Items - allow wrapping of long names
    for (var item in items) {
      _printFormalItem(buffer, item, nameWidth, qtyWidth, unitWidth, totalWidth, currencySymbol);
    }

    buffer.printDashedLine();

    // Totals (right aligned)
    buffer.setAlignment(EscPosAlignment.right);
    buffer.printText(_formatTotalLine('Subtotal:', subtotal, charsPerLine, currencySymbol));

    if (discount > 0) {
      buffer.printText(_formatTotalLine('Discount:', -discount, charsPerLine, currencySymbol));
    }

    if (tax > 0) {
      buffer.printText(_formatTotalLine('Tax:', tax, charsPerLine, currencySymbol));
    }

    buffer.printDashedLine();
    buffer.printText(_formatTotalLine('TOTAL:', total, charsPerLine, currencySymbol), bold: true, fontSize: EscPosFontSize.large);

    // Payment method and footer notes
    buffer.setAlignment(EscPosAlignment.center);
    buffer.printText('Payment: $paymentMethod');

    if (notes != null && notes.isNotEmpty) {
      buffer.setAlignment(EscPosAlignment.left);
      buffer.printText('Notes:', bold: true);
      for (var line in notes.split('\n')) {
        buffer.printText(line);
      }
    }

    buffer.setAlignment(EscPosAlignment.left);
    buffer.printText('Authorized Signature:');
    buffer.printText('______________________________');

    buffer.setAlignment(EscPosAlignment.center);
    buffer.printText('Thank you for your business!', bold: true);

    // Optional QR code (if invoiceUrl provided)
    if (showQrCode && invoiceUrl != null && invoiceUrl.isNotEmpty) {
      buffer.printQrCode(invoiceUrl, size: 4, errorCorrection: 48);
    }

    
    buffer.setAlignment(EscPosAlignment.center);
    buffer.printText('Powered by Manage Care', fontSize: EscPosFontSize.small);
    buffer.printLine();
    buffer.cutPaper();

    return buffer.getBytes();
  }

  static void _printItem(EscPosBuffer buffer, ReceiptLineItem item, int charsPerLine) {
    final displayName = _displayItemName(item);
    final itemName =
        displayName.length > 12 ? displayName.substring(0, 12) : displayName;
    final qtyDecimals = _getDecimalPlacesForUnit(item.unit);
    final qty = item.quantity.toStringAsFixed(qtyDecimals).padLeft(4);
    final price = '${item.unitPrice.toStringAsFixed(2)}'.padLeft(6);
    final total = '${item.total.toStringAsFixed(2)}'.padLeft(8);

    buffer.printText(_padRight(itemName, 12) + qty + price + total);
  }

  static void _printFormalItem(EscPosBuffer buffer, ReceiptLineItem item, int nameWidth, int qtyWidth, int unitWidth, int totalWidth, String currencySymbol) {
    final wrapped = _wrapText(_displayItemName(item), nameWidth);
    final qtyDecimals = _getDecimalPlacesForUnit(item.unit);
    final qtyStr = item.quantity.toStringAsFixed(qtyDecimals).padLeft(qtyWidth);
    final unitStr = _formatCurrency(item.unitPrice, currencySymbol).padLeft(unitWidth);
    final totalStr = _formatCurrency(item.total, currencySymbol).padLeft(totalWidth);

    // First line with numbers
    buffer.printText(_padRight(wrapped.first, nameWidth) + qtyStr + unitStr + totalStr);

    // Remaining lines (if any) just print the rest of the name
    for (var i = 1; i < wrapped.length; i++) {
      buffer.printText(_padRight(wrapped[i], nameWidth));
    }
  }

  static List<String> _wrapText(String text, int width) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (var w in words) {
      // If a single word is longer than width, break it into chunks
      if (w.length > width) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        for (var i = 0; i < w.length; i += width) {
          final end = (i + width > w.length) ? w.length : i + width;
          lines.add(w.substring(i, end));
        }
      } else {
        if (current.isEmpty) {
          current = w;
        } else if ((current.length + 1 + w.length) <= width) {
          current = '$current $w';
        } else {
          lines.add(current);
          current = w;
        }
      }
    }
    if (current.isNotEmpty) lines.add(current);
    // Ensure at least one line
    if (lines.isEmpty) lines.add('');
    return lines;
  }

  static String _padRight(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text + ' ' * (width - text.length);
  }

  static String _padLeft(String text, int width) {
    if (text.length >= width) return text.substring(text.length - width);
    return ' ' * (width - text.length) + text;
  }

  static String _formatTotalLine(String label, double amount, int charsPerLine, String currencySymbol) {
    final formattedAmount = '${currencySymbol}${amount.toStringAsFixed(2)}';
    final totalWidth = charsPerLine;
    final spacing = totalWidth - label.length - formattedAmount.length;
    return label + ' ' * (spacing > 1 ? spacing : 1) + formattedAmount;
  }

  static String _formatCurrency(double amount, String currencySymbol) {
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  /// Determine the appropriate number of decimal places for a quantity based on its unit
  static int _getDecimalPlacesForUnit(String? unit) {
    if (unit == null || unit.isEmpty) return 0; // Default: no decimals for unspecified units
    
    final unitLower = unit.toLowerCase();
    
    // Volume/Fuel units: use 2 decimals
    if (['l', 'litre', 'liter', 'ltr', 'liters', 'litres', 'gallon', 'gal', 'ml', 'milliliter'].contains(unitLower)) {
      return 2;
    }
    
    // Cylinder/Gas tank units: use 2 decimals (can be fractional)
    if (['cyl', 'cylinder', 'cylinders', 'tank', 'tanks'].contains(unitLower)) {
      return 2;
    }
    
    // Weight units: use 2 decimals
    if (['kg', 'gram', 'g', 'lbs', 'lb', 'oz', 'ounce'].contains(unitLower)) {
      return 2;
    }
    
    // Count/Quantity units: use 0 decimals
    if ([
      'unit',
      'units',
      'pcs',
      'pieces',
      'pc',
      'piece',
      'count',
      'no',
      'nos',
      'items',
      'item',
      'pack',
      'packs',
      'pac',
      'pacs',
      'pkt',
      'pkts',
      'bag',
      'bags',
      'box',
      'boxes',
      'bottle',
      'bottles',
      'carton',
      'cartons',
      'sachet',
      'sachets',
      'roll',
      'rolls',
    ].contains(unitLower)) {
      return 0;
    }
    
    // Default: 2 decimals for liquid/continuous measurements
    return 2;
  }

  static String _displayItemName(ReceiptLineItem item) {
    final unit = item.unit?.trim() ?? '';
    if (unit.isEmpty) {
      return item.name;
    }
    final normalizedName = item.name.toLowerCase();
    final normalizedUnit = unit.toLowerCase();
    if (normalizedName.contains('($normalizedUnit)') ||
        normalizedName.endsWith(' $normalizedUnit')) {
      return item.name;
    }
    return '${item.name} ($unit)';
  }
}

/// Receipt line item model
class ReceiptLineItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double total;
  final String? unit; // e.g. 'L', 'kg', 'litre', 'cyl'

  ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.unit,
  });
}

/// ESC/POS text alignment
enum EscPosAlignment {
  left,   // 0x00
  center, // 0x01
  right,  // 0x02
}

/// ESC/POS font sizes
enum EscPosFontSize {
  small,  // 0x00
  large,  // 0x11
}

/// ESC/POS Buffer for building receipt bytes
class EscPosBuffer {
  final int paperWidth; // 58 or 80
  final List<int> _buffer = [];

  EscPosBuffer(this.paperWidth);

  /// Initialize printer
  void initializePrinter() {
    _addBytes([0x1B, 0x40]); // ESC @ - Initialize
  }

  /// Print text
  void printText(
    String text, {
    bool bold = false,
    EscPosFontSize fontSize = EscPosFontSize.small,
    bool underline = false,
  }) {
    // Set bold
    if (bold) {
      _addBytes([0x1B, 0x45, 0x01]); // ESC E 1 - Bold on
    }

    // Set font size
    if (fontSize == EscPosFontSize.large) {
      _addBytes([0x1B, 0x21, 0x11]); // ESC ! 0x11 - Large font
    } else {
      _addBytes([0x1B, 0x21, 0x00]); // ESC ! 0x00 - Normal font
    }

    // Set underline
    if (underline) {
      _addBytes([0x1B, 0x2D, 0x01]); // ESC - 1 - Underline on
    }

    // Normalize unsupported chars (naira -> NGN)
    final printable = text.replaceAll('₦', 'NGN ');
    // Send UTF-8 encoded bytes (practical & safer than codeUnits)
    _addBytes(utf8.encode(printable));
    _addBytes([0x0A]); // LF - Line feed

    // Reset formatting
    if (bold) {
      _addBytes([0x1B, 0x45, 0x00]); // ESC E 0 - Bold off
    }
    if (underline) {
      _addBytes([0x1B, 0x2D, 0x00]); // ESC - 0 - Underline off
    }
  }

  /// Print line
  void printLine() {
    _addBytes([0x0A]); // LF - Line feed
  }

  /// Print dashed line
  void printDashedLine() {
    final width = paperWidth == 58 ? 30 : 48;
    final line = '-' * width;
    _addBytes(line.codeUnits);
    _addBytes([0x0A]); // LF - Line feed
  }

  /// Set text alignment
  void setAlignment(EscPosAlignment alignment) {
    final value = alignment.index;
    _addBytes([0x1B, 0x61, value]); // ESC a n - Alignment
  }

  /// Cut paper
  void cutPaper() {
    _addBytes([0x1D, 0x56, 0x00]); // GS V 0 - Cut paper
  }

  /// Add raw bytes
  void _addBytes(List<int> bytes) {
    _buffer.addAll(bytes);
  }

  /// Print QR Code (ESC/POS)
  /// Uses common ESC/POS sequence: select model, set size, set error correction, store data, then print
  void printQrCode(String data, {int size = 6, int errorCorrection = 48}) {
    final bytes = data.codeUnits;

    // [1] Select model: 1D 28 6B 04 00 31 41 32 00 (model 2)
    _addBytes([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // [2] Set size: 1D 28 6B 03 00 31 43 n
    final s = size.clamp(1, 16);
    _addBytes([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, s]);

    // [3] Set error correction: 1D 28 6B 03 00 31 45 n (48..51)
    final e = (errorCorrection < 48 || errorCorrection > 51) ? 48 : errorCorrection;
    _addBytes([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, e]);

    // [4] Store data: 1D 28 6B pL pH 31 50 30 ...data
    final len = bytes.length + 3;
    final pL = len & 0xFF;
    final pH = (len >> 8) & 0xFF;
    _addBytes([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    _addBytes(bytes);

    // [5] Print QR code: 1D 28 6B 03 00 31 51 30
    _addBytes([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    // Add spacing after QR
    _addBytes([0x0A, 0x0A]);
  }

  /// Get final bytes
  Uint8List getBytes() {
    return Uint8List.fromList(_buffer);
  }
}
