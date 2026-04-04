import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/pharmacy_provider.dart';
import '../widgets/receipt_print_dialog.dart';
import 'package:flutter/material.dart';

class PrescriptionPrintService {
  static Future<Uint8List> generatePdfBytes({
    required String businessName,
    required Prescription prescription,
    required String patientName,
    required List<Map<String, dynamic>> itemRows,
    int? patientAge,
  }) async {
    final pdf = pw.Document();
    final formatter = DateFormat('dd MMM yyyy, HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            businessName,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Prescription',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Prescription ID: ${prescription.id}'),
                pw.SizedBox(height: 4),
                pw.Text('Patient: $patientName'),
                if (patientAge != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Age: $patientAge'),
                ],
                pw.SizedBox(height: 4),
                pw.Text('Status: ${prescription.status.toUpperCase()}'),
                pw.SizedBox(height: 4),
                pw.Text('Issued: ${formatter.format(prescription.createdAt)}'),
                if ((prescription.prescriber ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Prescriber: ${prescription.prescriber}'),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: const ['Drug', 'Qty'],
            data: itemRows
                .map((row) => [
                      row['name']?.toString() ?? 'Unknown drug',
                      row['qty']?.toString() ?? '1',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
          ),
          if ((prescription.notes ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Prescription Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(prescription.notes!.trim()),
          ],
          if ((prescription.attachmentReference ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              prescription.attachmentRequired
                  ? 'Required Attachment Reference'
                  : 'Attachment Reference',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(prescription.attachmentReference!.trim()),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated from Manage Care',
            style: const pw.TextStyle(
              color: PdfColors.grey700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static Future<void> printPrescription(
    BuildContext context, {
    required String businessName,
    required Prescription prescription,
    required String patientName,
    required List<Map<String, dynamic>> itemRows,
    int? patientAge,
  }) async {
    final pdfBytes = await generatePdfBytes(
      businessName: businessName,
      prescription: prescription,
      patientName: patientName,
      itemRows: itemRows,
      patientAge: patientAge,
    );

    if (!context.mounted) return;

    await showReceiptPrintDialog(
      context,
      pdfBytes: pdfBytes,
      receiptNumber: prescription.id,
    );
  }
}
