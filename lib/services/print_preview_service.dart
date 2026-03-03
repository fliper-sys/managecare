import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

/// Service for managing print previews with proper paper size configuration
class PrintPreviewService {
  /// Show print preview for receipt with thermal printer settings
  static Future<void> showReceiptPrintPreview(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String receiptNumber,
    required String paperWidth, // '58' or '80'
    String? jobName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => Future.value(pdfBytes),
      name: jobName ?? 'Receipt_$receiptNumber',
      format: _getPdfPageFormat(paperWidth),
      usePrinterSettings: false,
    );
  }

  /// Show print preview for multiple receipts
  static Future<void> showMultiplePrintPreview(
    BuildContext context, {
    required List<Uint8List> pdfList,
    required String paperWidth,
    String? jobName,
  }) async {
    // For multiple receipts, show the first and let user handle batch
    if (pdfList.isNotEmpty) {
      await showReceiptPrintPreview(
        context,
        pdfBytes: pdfList.first,
        receiptNumber: 'batch',
        paperWidth: paperWidth,
        jobName: jobName ?? 'Receipts_Batch',
      );
    }
  }

  /// Get proper PDF page format for thermal printer
  static PdfPageFormat _getPdfPageFormat(String paperWidth) {
    if (paperWidth == '58') {
      // Thermal printer: 58mm width x 300mm height
      // 58mm ≈ 164 points, 300mm ≈ 850 points
      return const PdfPageFormat(164, 850, marginAll: 0);
    } else {
      // Standard printer: 80mm x 300mm
      // 80mm ≈ 227 points, 300mm ≈ 850 points
      return const PdfPageFormat(227, 850, marginAll: 0);
    }
  }

  /// Get print paper size name for reference
  static String getPaperSizeName(String paperWidth) {
    return paperWidth == '58' ? 'Thermal 58mm' : 'Thermal 80mm';
  }

  /// Check if device supports printing
  static Future<bool> canPrintToPdf() async {
    try {
      // If we can show layout dialog, we can print to PDF
      return true; // Most devices support this
    } catch (e) {
      return false;
    }
  }

  /// Print directly without preview (web: shows print dialog)
  static Future<bool> printDirectly({
    required Uint8List pdfBytes,
    required String receiptNumber,
    required String paperWidth,
  }) async {
    try {
      // On web and most platforms, layoutPdf handles the print dialog
      await Printing.layoutPdf(
        onLayout: (_) => Future.value(pdfBytes),
        format: _getPdfPageFormat(paperWidth),
        usePrinterSettings: false,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
