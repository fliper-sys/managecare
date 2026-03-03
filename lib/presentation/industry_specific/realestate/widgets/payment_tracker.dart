import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/real_estate_provider.dart';

class PaymentTracker extends StatelessWidget {
  final List<RentPayment> payments;

  const PaymentTracker({super.key, required this.payments});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: payments.length,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final payment = payments[index];
        final date = DateFormat('dd MMM yyyy').format(payment.dueDate);
        return ListTile(
          title: Text(date),
          subtitle: Text(payment.paymentMethod),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₦${payment.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: payment.status == 'paid'
                        ? Colors.green[100]
                        : (payment.status == 'overdue'
                            ? Colors.red[100]
                            : Colors.orange[100]),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(payment.status.toUpperCase(),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}

