import 'package:flutter/material.dart';

/// Widget to display invoice-specific receipt details
/// Used for retail, drinks, and other businesses with large orders
class InvoiceReceiptWidget extends StatelessWidget {
  final String businessName;
  final String? businessLogo;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerAddress;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String notes;
  final String? termsConditions;
  final String paymentMethod;
  final String status;

  const InvoiceReceiptWidget({
    super.key,
    required this.businessName,
    this.businessLogo,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.customerAddress,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.notes,
    this.termsConditions,
    required this.paymentMethod,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildInvoiceHeader(),
          const SizedBox(height: 32),

          // Invoice Details
          _buildInvoiceDetails(),
          const SizedBox(height: 32),

          // Customer Details
          if (customerAddress != null || customerEmail != null)
            _buildCustomerSection(),
          const SizedBox(height: 32),

          // Items Table
          _buildItemsTable(),
          const SizedBox(height: 24),

          // Totals Section
          _buildTotalsSection(),
          const SizedBox(height: 24),

          // Notes
          if (notes.isNotEmpty) ...[
            _buildNotesSection(),
            const SizedBox(height: 24),
          ],

          // Terms & Conditions
          if (termsConditions != null && termsConditions!.isNotEmpty) ...[
            _buildTermsSection(),
            const SizedBox(height: 24),
          ],

          // Footer
          _buildInvoiceFooter(),
        ],
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'INVOICE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor(status)),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceDetails() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Invoice #', invoiceNumber),
            const SizedBox(height: 12),
            _buildDetailRow('Invoice Date', _formatDate(invoiceDate)),
            if (dueDate != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow('Due Date', _formatDate(dueDate!)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bill To:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(customerName, style: const TextStyle(fontSize: 14)),
        if (customerAddress != null)
          Text(customerAddress!, style: const TextStyle(fontSize: 14)),
        if (customerEmail != null)
          Text(customerEmail!, style: const TextStyle(fontSize: 14)),
        if (customerPhone != null)
          Text(customerPhone!, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Qty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Price',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Amount',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isAlternate = index.isEven;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: isAlternate ? Colors.grey[50] : Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.description.isNotEmpty)
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    item.quantity.toStringAsFixed(2),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    '\$${item.unitPrice.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    '\$${item.total.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTotalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Subtotal: ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '\$${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (taxAmount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Tax: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '\$${taxAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        if (discountAmount > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Discount: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[600],
                ),
              ),
              Text(
                '-\$${discountAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Divider(thickness: 2),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Total: ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '\$${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          notes,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTermsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Terms & Conditions:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          termsConditions!,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildInvoiceFooter() {
    return Center(
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Thank you for your business!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment Method: $paymentMethod',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

class InvoiceItem {
  final String name;
  final String description;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;

  InvoiceItem({
    required this.name,
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });
}

