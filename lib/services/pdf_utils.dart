import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

/// Utilities for consistent PDF generation across the app.
/// - Loads a robust font that supports common currency symbols (e.g., ₦)
///   Tries bundled `assets/fonts/NotoSans-Regular.ttf`, falls back to fetching
///   the font from Google Fonts' GitHub raw URL at runtime, and finally
///   falls back to the built-in Helvetica if nothing else is available.
/// - Loads Manage Care or business logo bytes (tries business logo URL, falls back to bundled logo)
/// - Provides a reusable header widget

class PdfFontResult {
  final pw.Font font;
  final bool supportsNaira;
  PdfFontResult(this.font, {required this.supportsNaira});
}

Future<PdfFontResult> loadDefaultPdfFont() async {
  // 1) Try bundled font asset (recommended for offline reliability)
  try {
    final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final font = pw.Font.ttf(data.buffer.asByteData());
    // Noto Sans includes the ₦ glyph
    return PdfFontResult(font, supportsNaira: true);
  } catch (_) {
    // continue to next option
  }

  // 2) Try fetching Noto Sans at runtime from Google Fonts GitHub raw (best-effort)
  try {
    final url = 'https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans-Regular.ttf';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
      final font = pw.Font.ttf(ByteData.view(res.bodyBytes.buffer));
      return PdfFontResult(font, supportsNaira: true);
    }
  } catch (_) {
    // ignore and fallback
  }

  // 3) Fallback to Helvetica (no guarantee for ₦ glyph)
  return PdfFontResult(pw.Font.helvetica(), supportsNaira: false);
}

Future<Uint8List?> loadBusinessLogoBytes({String? logoUrl}) async {
  // Try remote logo first
  try {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final res = await http.get(Uri.parse(logoUrl));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res.bodyBytes;
    }
  } catch (_) {
    // ignore network errors and fallback to bundled asset
  }

  // Fallback to bundled Manage Care logo
  try {
    final data = await rootBundle.load('assets/images/splash/logo.png');
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

pw.Widget buildPdfHeader({
  required pw.Font font,
  String businessName = 'Manage Care',
  String? businessDetails,
  Uint8List? logoBytes,
  String? stylePreset,
  String? accentColorHex,
}) {
  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  // Resolve accent color
  PdfColor resolveAccent() {
    try {
      if (accentColorHex != null && accentColorHex.startsWith('#')) {
        final hex = accentColorHex.replaceFirst('#', '');
        final v = int.parse('FF$hex', radix: 16);
        return PdfColor.fromInt(v);
      }
    } catch (_) {}
    return PdfColor.fromInt(0xFF2C3E50);
  }

  final accent = resolveAccent();

  // Minimal preset: simple header text (no colored band)
  if (stylePreset == 'minimal') {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Image(pw.MemoryImage(logoBytes), width: 48, height: 48),
            if (logoBytes != null) pw.SizedBox(width: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                if (businessDetails != null && businessDetails.isNotEmpty)
                  pw.Text(businessDetails, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColor.fromInt(0xFF666666))),
              ],
            ),
            pw.Spacer(),
            pw.Text('Generated: $now', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColor.fromInt(0xFF666666))),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // Professional or Colorful - show colored band using accent color
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: accent),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoBytes != null)
              pw.Container(
                decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Image(pw.MemoryImage(logoBytes), width: 48, height: 48),
              ),
            if (logoBytes != null) pw.SizedBox(width: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName, style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                if (businessDetails != null && businessDetails.isNotEmpty)
                  pw.Text(businessDetails, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColor.fromInt(0xFFECECEC))),
              ],
            ),
            pw.Spacer(),
            pw.Text('Generated: $now', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColor.fromInt(0xFFB0BEC5))),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.SizedBox(height: 8),
    ],
  );
}
