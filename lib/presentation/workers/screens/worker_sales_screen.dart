import 'package:flutter/material.dart';

import '../../sales/screens/sales_screen.dart';

class WorkerSalesScreen extends StatelessWidget {
  const WorkerSalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SalesScreen(
      title: 'Worker Sales',
      enableStoreSwitcher: true,
    );
  }
}
