import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../services/notification_and_email_service.dart';
import '../providers/real_estate_provider.dart';

class RentCollectionDialog extends StatefulWidget {
  final RealEstateProvider provider;
  final RentPayment payment;
  final Tenant tenant;
  final Lease lease;
  final String businessEmail;
  final String businessName;

  const RentCollectionDialog({
    Key? key,
    required this.provider,
    required this.payment,
    required this.tenant,
    required this.lease,
    required this.businessEmail,
    required this.businessName,
  }) : super(key: key);

  @override
  State<RentCollectionDialog> createState() => _RentCollectionDialogState();
}

class _RentCollectionDialogState extends State<RentCollectionDialog> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _uploadReceiptAndMarkPaid() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.any);
      if (result == null) {
        // user cancelled
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        setState(() => _errorMessage = 'Selected file has no path');
        return;
      }

      final file = File(path);
      final uploadedUrl = await widget.provider.uploadPropertyDocument(file);
      if (uploadedUrl == null) {
        setState(() => _errorMessage = 'Failed to upload receipt');
        return;
      }

      final now = DateTime.now();
      await widget.provider.updateRentPaymentStatus(
        widget.payment.id,
        'paid',
        paidDate: now,
        receiptUrl: uploadedUrl,
        paymentMethod: 'receipt_upload',
      );

      // Send owner notification
      try {
        await NotificationAndEmailService().sendSalesNotification(
          ownerEmail: widget.businessEmail,
          businessName: widget.businessName,
          customerName: widget.tenant.name,
          customerEmail: widget.tenant.email,
          totalAmount: widget.payment.amount,
          items: [
            {'name': 'Rent Payment', 'quantity': 1, 'price': widget.payment.amount}
          ],
          paymentMethod: 'Receipt Upload',
          receiptNumber: widget.payment.id,
        );
      } catch (e) {
        // Log but don't block on notification errors
        print('Error sending notification: $e');
      }

      setState(() {
        _successMessage = 'Receipt uploaded and payment recorded successfully';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error uploading receipt: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markAsPaidManually() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      await widget.provider.updateRentPaymentStatus(
        widget.payment.id,
        'paid',
        paidDate: now,
      );

      // Send notification
      try {
        await NotificationAndEmailService().sendSalesNotification(
          ownerEmail: widget.businessEmail,
          businessName: widget.businessName,
          customerName: widget.tenant.name,
          customerEmail: widget.tenant.email,
          totalAmount: widget.payment.amount,
          items: [
            {'name': 'Rent Payment', 'quantity': 1, 'price': widget.payment.amount}
          ],
          paymentMethod: 'Manual Entry',
          receiptNumber: widget.payment.id,
        );
      } catch (e) {
        print('Error sending notification: $e');
      }

      setState(() => _successMessage = 'Payment recorded successfully');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error recording payment: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₦', locale: 'en_NG');

    return AlertDialog(
      title: const Text('Collect Rent Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tenant: ${widget.tenant.name}', style: AppTextStyles.body1),
            const SizedBox(height: 8),
            Text('Amount: ${currencyFormat.format(widget.payment.amount)}', style: AppTextStyles.heading3.copyWith(color: AppColors.primary)),
            const SizedBox(height: 8),
            Text('Due Date: ${DateFormat('yyyy-MM-dd').format(widget.payment.dueDate)}', style: AppTextStyles.body2),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isProcessing ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: _isProcessing ? null : _markAsPaidManually,
          child: const Text('Mark as Paid'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _uploadReceiptAndMarkPaid,
          child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Upload Receipt'),
        ),
      ],
    );
  }
}
