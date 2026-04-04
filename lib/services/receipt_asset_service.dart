import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'pdf_utils.dart';

class ReceiptAssetService {
  static Future<Uint8List> generateReceiptImage({
    required String businessName,
    required String receiptText,
    String? receiptNumber,
    String title = 'RECEIPT',
    String? businessLogoUrl,
    String? subscriptionTier,
    String? businessClass,
  }) async {
    final normalizedText = receiptText.replaceAll('\r\n', '\n').trim();
    final lines = normalizedText.isEmpty
        ? const <String>['Receipt unavailable']
        : normalizedText.split('\n');
    final manageCareLogo = await _loadManageCareLogo();
    final businessLogo = await _loadBusinessLogo(
      businessLogoUrl: businessLogoUrl,
      subscriptionTier: subscriptionTier,
      businessClass: businessClass,
    );

    const width = 720.0;
    const cardInset = 18.0;
    const horizontalPadding = 32.0;
    final hasBusinessLogo = businessLogo != null;
    final headerHeight = hasBusinessLogo ? 170.0 : 132.0;
    const footerHeight = 52.0;
    final bodyWidth = width - ((cardInset + horizontalPadding) * 2);

    final businessPainter = _buildPainter(
      text: businessName,
      maxWidth: bodyWidth,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );

    final titlePainter = _buildPainter(
      text: receiptNumber == null || receiptNumber.isEmpty
          ? title
          : '$title  #$receiptNumber',
      maxWidth: bodyWidth,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFE2E8F0),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );

    final linePainters = lines
        .map(
          (line) => _buildPainter(
            text: line.isEmpty ? ' ' : line,
            maxWidth: bodyWidth,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              height: 1.45,
              fontFamily: 'monospace',
            ),
          ),
        )
        .toList();

    final footerPainter = _buildPainter(
      text: 'Powered by Manage Care',
      maxWidth: bodyWidth,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );

    var bodyHeight = 0.0;
    for (final painter in linePainters) {
      bodyHeight += painter.height + 6;
    }

    final height = cardInset +
        headerHeight +
        28 +
        bodyHeight +
        footerHeight +
        cardInset;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width, height);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F5F9),
    );

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cardInset,
        cardInset,
        width - (cardInset * 2),
        height - (cardInset * 2),
      ),
      const Radius.circular(24),
    );

    canvas.drawShadow(
      Path()..addRRect(cardRect),
      Colors.black.withOpacity(0.12),
      16,
      true,
    );
    canvas.drawRRect(cardRect, Paint()..color = Colors.white);

    final headerRect = Rect.fromLTWH(
      cardInset,
      cardInset,
      width - (cardInset * 2),
      headerHeight,
    );
    final headerRRect = RRect.fromRectAndCorners(
      headerRect,
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
      bottomLeft: const Radius.circular(18),
      bottomRight: const Radius.circular(18),
    );
    canvas.drawRRect(
      headerRRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1E3A8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(headerRect),
    );

    if (businessLogo != null) {
      final logoCardRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (width / 2) - 34,
          cardInset + 14,
          68,
          68,
        ),
        const Radius.circular(22),
      );
      canvas.drawShadow(
        Path()..addRRect(logoCardRect),
        Colors.black.withOpacity(0.12),
        10,
        true,
      );
      canvas.drawRRect(logoCardRect, Paint()..color = Colors.white);
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH((width / 2) - 24, cardInset + 24, 48, 48),
        image: businessLogo,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    final businessNameTop = cardInset + (hasBusinessLogo ? 96 : 32);
    final titleTop = businessNameTop + 46;
    businessPainter.paint(
      canvas,
      Offset(
        (width - businessPainter.width) / 2,
        businessNameTop,
      ),
    );
    titlePainter.paint(
      canvas,
      Offset(
        (width - titlePainter.width) / 2,
        titleTop,
      ),
    );

    var y = cardInset + headerHeight + 28;
    canvas.drawLine(
      Offset(cardInset + 24, y - 10),
      Offset(width - cardInset - 24, y - 10),
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 1,
    );

    for (final painter in linePainters) {
      painter.paint(canvas, Offset(cardInset + horizontalPadding, y));
      y += painter.height + 6;
    }

    final footerTop = y + 10;
    final footerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cardInset + 20,
        footerTop,
        width - ((cardInset + 20) * 2),
        footerHeight - 14,
      ),
      const Radius.circular(18),
    );

    canvas.drawRRect(
      footerRect,
      Paint()..color = const Color(0xFFF8FAFC),
    );
    canvas.drawRRect(
      footerRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE2E8F0),
    );

    final footerCenterY = footerTop + ((footerHeight - 14) / 2);
    const logoSize = 22.0;
    final textX =
        manageCareLogo != null ? (width / 2) - (footerPainter.width / 2) + 18 : (width - footerPainter.width) / 2;

    if (manageCareLogo != null) {
      final logoRect = Rect.fromLTWH(
        textX - 30,
        footerCenterY - (logoSize / 2),
        logoSize,
        logoSize,
      );
      paintImage(
        canvas: canvas,
        rect: logoRect,
        image: manageCareLogo,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    footerPainter.paint(
      canvas,
      Offset(
        textX,
        footerCenterY - (footerPainter.height / 2),
      ),
    );

    final image = await recorder.endRecording().toImage(width.ceil(), height.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to render receipt image.');
    }

    return byteData.buffer.asUint8List();
  }

  static Future<ui.Image?> _loadManageCareLogo() async {
    try {
      final data = await rootBundle.load('assets/images/splash/logo.png');
      return _decodeImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> _loadBusinessLogo({
    String? businessLogoUrl,
    String? subscriptionTier,
    String? businessClass,
  }) async {
    try {
      if (!canUseBusinessLogoOnDocument(
        subscriptionTier: subscriptionTier,
        businessClass: businessClass,
      )) {
        return null;
      }
      final bytes = await loadRemoteLogoBytes(businessLogoUrl);
      if (bytes == null || bytes.isEmpty) return null;
      return _decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  static TextPainter _buildPainter({
    required String text,
    required double maxWidth,
    required TextStyle style,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    )..layout(maxWidth: maxWidth);
    return painter;
  }
}
