import 'package:flutter/material.dart';
import 'dart:io';
import '../services/email_receipt_service.dart';
import '../services/receipt_sharing_service.dart';
import 'package:business_manager/core/utils/formatters.dart';

class ReceiptConfirmationDialog extends StatefulWidget {
  final String receiptNumber;
  final String businessName;
  final String customerName;
  final String? customerEmail;
  final double totalAmount;
  final File pdfFile;

  const ReceiptConfirmationDialog({
    super.key,
    required this.receiptNumber,
    required this.businessName,
    required this.customerName,
    required this.customerEmail,
    required this.totalAmount,
    required this.pdfFile,
  });

  @override
  State<ReceiptConfirmationDialog> createState() =>
      _ReceiptConfirmationDialogState();
}

class _ReceiptConfirmationDialogState extends State<ReceiptConfirmationDialog> {
  bool _isSending = false;
  final _emailService = EmailReceiptService();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receipt Generated'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt #${widget.receiptNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(widget.totalAmount),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'How would you like to handle this receipt?',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            _buildReceiptOption(
              icon: Icons.email_rounded,
              title: 'Send via Email',
              subtitle: widget.customerEmail ?? 'No email provided',
              onTap: widget.customerEmail != null
                  ? (_isSending ? null : () => _sendViaEmail())
                  : null,
              isLoading: _isSending,
            ),
            const SizedBox(height: 12),
            _buildReceiptOption(
              icon: Icons.share_rounded,
              title: 'Share Receipt',
              subtitle: 'Share via WhatsApp, Email, etc.',
              onTap: _isSending ? null : () => _shareReceipt(),
              isLoading: _isSending,
            ),
            const SizedBox(height: 12),
            _buildReceiptOption(
              icon: Icons.file_download_rounded,
              title: 'Download Only',
              subtitle: 'Save to device',
              onTap: () => _downloadOnly(),
              isLoading: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildReceiptOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: onTap == null ? Colors.grey[300]! : Colors.blue[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: onTap == null ? Colors.grey : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: onTap == null ? Colors.grey : Colors.black,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendViaEmail() async {
    if (_isSending) return;
    if (widget.customerEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address provided')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final success = await _emailService.sendReceiptEmail(
        recipientEmail: widget.customerEmail!,
        receiptNumber: widget.receiptNumber,
        businessName: widget.businessName,
        pdfFile: widget.pdfFile,
        totalAmount: widget.totalAmount,
        customerName: widget.customerName,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Receipt sent to ${widget.customerEmail}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send receipt email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _shareReceipt() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await ReceiptSharingService.shareReceiptPdf(
        pdfFile: widget.pdfFile,
        receiptNumber: widget.receiptNumber,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _downloadOnly() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt saved to device'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

