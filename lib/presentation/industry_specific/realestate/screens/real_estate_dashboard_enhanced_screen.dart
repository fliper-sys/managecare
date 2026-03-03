// DEPRECATED: This enhanced screen has been merged into
// `realestate_dashboard_screen.dart`. Keep this wrapper for
// backward compatibility; use `RealestateDashboardScreen` instead.

import 'package:flutter/material.dart';
import 'realestate_dashboard_screen.dart';

class RealEstateDashboardScreenEnhanced extends StatelessWidget {
  const RealEstateDashboardScreenEnhanced({super.key});

  @override
  Widget build(BuildContext context) {
    // Forward to the canonical RealestateDashboardScreen to avoid
    // duplicated implementation and ensure a single source of truth.
    return const RealestateDashboardScreen();
  }
}
             