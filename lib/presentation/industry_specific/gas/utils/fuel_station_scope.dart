import 'package:flutter/material.dart';

enum FuelStationMode { gas, petroleum }

extension FuelStationModeLabel on FuelStationMode {
  String get label {
    switch (this) {
      case FuelStationMode.petroleum:
        return 'Petroleum Station';
      case FuelStationMode.gas:
        return 'Gas Plant';
    }
  }

  String get storageValue {
    switch (this) {
      case FuelStationMode.petroleum:
        return 'petroleum';
      case FuelStationMode.gas:
        return 'gas';
    }
  }
}

class FuelStationScope {
  static bool isPetroleumBusiness(String businessType) {
    final value = businessType.trim().toLowerCase();
    return value.contains('petroleum') ||
        value.contains('petrol') ||
        value.contains('filling');
  }

  static bool isGasBusiness(String businessType) {
    final value = businessType.trim().toLowerCase();
    return value.contains('gas') && !isPetroleumBusiness(value);
  }

  static bool matches(FuelStationMode mode, String? businessType) {
    final value = businessType?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return true;
    switch (mode) {
      case FuelStationMode.petroleum:
        return isPetroleumBusiness(value);
      case FuelStationMode.gas:
        return isGasBusiness(value);
    }
  }

  static Widget mismatchScaffold({
    required FuelStationMode mode,
    required String? businessType,
  }) {
    return Scaffold(
      appBar: AppBar(title: Text(mode.label)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${mode.label} tools cannot be used for '
            '${businessType?.trim().isEmpty == false ? businessType : 'this'} business.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
