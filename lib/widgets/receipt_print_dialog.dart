import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../services/print_preview_service.dart';

/// Dialog for receipt print preview with paper size options
class ReceiptPrintDialog extends StatefulWidget {
  final Uint8List pdfBytes;
  final String receiptNumber;
  final String initialPaperWidth; // '58' or '80'
  final VoidCallback? onPrintComplete;
  final VoidCallback? onCancel;

  const ReceiptPrintDialog({
    super.key,
    required this.pdfBytes,
    required this.receiptNumber,
    this.initialPaperWidth = '58',
    this.onPrintComplete,
    this.onCancel,
  });

  @override
  State<ReceiptPrintDialog> createState() => _ReceiptPrintDialogState();
}

class _ReceiptPrintDialogState extends State<ReceiptPrintDialog> {
  late String _selectedPaperWidth;
  bool _isProcessing = false;
  String? _supportedPrinters;

  @override
  void initState() {
    super.initState();
    _selectedPaperWidth = widget.initialPaperWidth;
    _checkPrintingCapabilities();
  }

  Future<void> _checkPrintingCapabilities() async {
    final canPrintToPdf = await PrintPreviewService.canPrintToPdf();
    
    setState(() {
      _supportedPrinters = 'Print to PDF: $canPrintToPdf';
    });
  }

  Future<void> _showPrintPreview() async {
    setState(() => _isProcessing = true);
    try {
      await PrintPreviewService.showReceiptPrintPreview(
        context,
        pdfBytes: widget.pdfBytes,
        receiptNumber: widget.receiptNumber,
        paperWidth: _selectedPaperWidth,
        jobName: 'Receipt_${widget.receiptNumber}',
      );
      widget.onPrintComplete?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _printDirectly() async {
    setState(() => _isProcessing = true);
    try {
      final result = await PrintPreviewService.printDirectly(
        pdfBytes: widget.pdfBytes,
        receiptNumber: widget.receiptNumber,
        paperWidth: _selectedPaperWidth,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? 'Print sent to printer' : 'Print cancelled'),
            backgroundColor: result ? Colors.green : Colors.orange,
          ),
        );
        if (result) {
          widget.onPrintComplete?.call();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.print, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Print Receipt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Receipt #${widget.receiptNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Paper size selector
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Printer Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Thermal 58mm',
                              style: TextStyle(fontSize: 13),
                            ),
                            subtitle: const Text(
                              '(Receipt printer)',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: '58',
                            groupValue: _selectedPaperWidth,
                            onChanged: _isProcessing
                                ? null
                                : (value) => setState(() => _selectedPaperWidth = value!),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Thermal 80mm',
                              style: TextStyle(fontSize: 13),
                            ),
                            subtitle: const Text(
                              '(Standard thermal)',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: '80',
                            groupValue: _selectedPaperWidth,
                            onChanged: _isProcessing
                                ? null
                                : (value) => setState(() => _selectedPaperWidth = value!),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Print capabilities info
              if (_supportedPrinters != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _supportedPrinters!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Page size automatically configured for minimal whitespace',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            widget.onCancel?.call();
                            Navigator.pop(context);
                          },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _showPrintPreview,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _printDirectly,
                    icon: _isProcessing
                        ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.print),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show receipt print dialog
Future<void> showReceiptPrintDialog(
  BuildContext context, {
  required Uint8List pdfBytes,
  required String receiptNumber,
  String initialPaperWidth = '58',
  VoidCallback? onPrintComplete,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ReceiptPrintDialog(
      pdfBytes: pdfBytes,
      receiptNumber: receiptNumber,
      initialPaperWidth: initialPaperWidth,
      onPrintComplete: onPrintComplete,
    ),
  );
}
