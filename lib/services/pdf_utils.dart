import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/currency.dart';
import 'subscription_service.dart';

/// Utilities for consistent PDF generation across the app.
class PdfFontResult {
  final pw.Font font;
  final bool supportsNaira;

  PdfFontResult(this.font, {required this.supportsNaira});
}

class PdfBrandingAssets {
  final pw.Font font;
  final bool supportsNaira;
  final String currencySymbol;
  final Uint8List? manageCareLogoBytes;
  final Uint8List? businessLogoBytes;
  final bool showBusinessLogo;

  const PdfBrandingAssets({
    required this.font,
    required this.supportsNaira,
    required this.currencySymbol,
    required this.manageCareLogoBytes,
    required this.businessLogoBytes,
    required this.showBusinessLogo,
  });
}

Future<PdfFontResult> loadDefaultPdfFont() async {
  try {
    final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final font = pw.Font.ttf(data.buffer.asByteData());
    return PdfFontResult(font, supportsNaira: true);
  } catch (_) {}

  try {
    final url =
        'https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans-Regular.ttf';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
      final font = pw.Font.ttf(ByteData.view(res.bodyBytes.buffer));
      return PdfFontResult(font, supportsNaira: true);
    }
  } catch (_) {}

  return PdfFontResult(pw.Font.helvetica(), supportsNaira: false);
}

String resolvePdfCurrencySymbol(bool supportsNaira) {
  return supportsNaira ? kNairaSymbol : kNairaFallbackSymbol;
}

Future<Uint8List?> loadManageCareLogoBytes() async {
  try {
    final data = await rootBundle.load('assets/images/splash/logo.png');
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> loadRemoteLogoBytes(String? logoUrl) async {
  try {
    if (logoUrl == null || logoUrl.trim().isEmpty) return null;
    final res = await http.get(Uri.parse(logoUrl.trim()));
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
      return res.bodyBytes;
    }
  } catch (_) {}
  return null;
}

Future<Uint8List?> loadBusinessLogoBytes({String? logoUrl}) async {
  return await loadRemoteLogoBytes(logoUrl) ?? await loadManageCareLogoBytes();
}

bool canUseBusinessLogoOnDocument({
  String? subscriptionTier,
  String? businessClass,
  bool allowWhenUnknown = false,
}) {
  final hasTierInfo =
      (subscriptionTier ?? '').trim().isNotEmpty ||
      (businessClass ?? '').trim().isNotEmpty;
  if (!hasTierInfo) return allowWhenUnknown;

  final normalizedTier = SubscriptionService.normalizeStoredPlanLevel(
    subscriptionTier: subscriptionTier,
    businessClass: businessClass,
  );
  return SubscriptionService.isTierAtLeast(normalizedTier, 'tier3');
}

Future<PdfBrandingAssets> loadPdfBranding({
  String? businessLogoUrl,
  String? subscriptionTier,
  String? businessClass,
  bool allowBusinessLogoWithoutTier = false,
}) async {
  final fontResult = await loadDefaultPdfFont();
  final manageCareLogoBytes = await loadManageCareLogoBytes();
  final showBusinessLogo =
      (businessLogoUrl ?? '').trim().isNotEmpty &&
      canUseBusinessLogoOnDocument(
        subscriptionTier: subscriptionTier,
        businessClass: businessClass,
        allowWhenUnknown: allowBusinessLogoWithoutTier,
      );

  final businessLogoBytes = showBusinessLogo
      ? await loadRemoteLogoBytes(businessLogoUrl)
      : null;

  return PdfBrandingAssets(
    font: fontResult.font,
    supportsNaira: fontResult.supportsNaira,
    currencySymbol: resolvePdfCurrencySymbol(fontResult.supportsNaira),
    manageCareLogoBytes: manageCareLogoBytes,
    businessLogoBytes: businessLogoBytes,
    showBusinessLogo: showBusinessLogo && businessLogoBytes != null,
  );
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

  PdfColor resolveAccent() {
    try {
      if (accentColorHex != null && accentColorHex.startsWith('#')) {
        final hex = accentColorHex.replaceFirst('#', '');
        final value = int.parse('FF$hex', radix: 16);
        return PdfColor.fromInt(value);
      }
    } catch (_) {}
    return PdfColor.fromInt(0xFF0F4C81);
  }

  final accent = resolveAccent();

  if (stylePreset == 'minimal') {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoBytes != null)
              pw.Container(
                width: 38,
                height: 38,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
              ),
            if (logoBytes != null) pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (businessDetails != null && businessDetails.trim().isNotEmpty)
                    pw.Text(
                      businessDetails,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
            pw.Text(
              now,
              style: pw.TextStyle(
                font: font,
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 6),
      ],
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoBytes != null)
              pw.Container(
                width: 50,
                height: 50,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
              ),
            if (logoBytes != null) pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  if (businessDetails != null && businessDetails.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        businessDetails,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColor.fromInt(0xFFE3EEF9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0x33FFFFFF),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(
                'Generated $now',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget buildDocumentFooter({
  required pw.Font font,
  Uint8List? manageCareLogoBytes,
  String poweredByText = 'Powered by Manage Care',
  bool compact = false,
}) {
  final logoSize = compact ? 14.0 : 18.0;
  final fontSize = compact ? 7.0 : 8.5;

  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (manageCareLogoBytes != null)
          pw.Image(
            pw.MemoryImage(manageCareLogoBytes),
            width: logoSize,
            height: logoSize,
            fit: pw.BoxFit.contain,
          ),
        if (manageCareLogoBytes != null) pw.SizedBox(width: 6),
        pw.Text(
          poweredByText,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            color: PdfColors.grey700,
          ),
        ),
      ],
    ),
  );
}
