import 'package:flutter/material.dart';

import '../../../sales/screens/sales_screen.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SalesScreen(
      title: 'Quick Sale',
      enableStoreSwitcher: true,
    );
  }
}
