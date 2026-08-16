// Copyright 2026 Manage Care. All rights reserved.
// Use of this source code is governed by an Apache 2.0 license
// that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'customer_display_platform_stub.dart'
    if (dart.library.io) 'customer_display_platform_io.dart' as platform;

/// Whether this build can talk to a serial COM port at all. False on web
/// (no dart:ffi) and on mobile (no bundled native library / not the target
/// hardware) - true only for the Windows/Linux/macOS desktop build.
bool get customerDisplaySupported => platform.platformIsSupported();

/// Common serial baud rates these pole displays ship configured for.
/// 9600 is by far the most common default.
const List<int> customerDisplayBaudRates = [2400, 4800, 9600, 19200, 38400, 115200];

const String _prefsKeyEnabled = 'customer_display_enabled';
const String _prefsKeyPort = 'customer_display_port';
const String _prefsKeyBaudRate = 'customer_display_baud_rate';

/// Drives a customer-facing pole/VFD display over a serial COM port using
/// the ESC/POS command subset these displays ship configured for out of the
/// box (confirmed against the unit's own diagnostic screen: "CommandType:
/// ESC/POS"). Settings (which port, which baud rate) are local to this PC -
/// a COM port name is meaningless on a different machine, so they're kept in
/// SharedPreferences rather than synced business-wide through Firestore.
class CustomerDisplayService {
  static final CustomerDisplayService _instance =
      CustomerDisplayService._internal();
  factory CustomerDisplayService() => _instance;
  CustomerDisplayService._internal();

  Object? _port;
  String? _connectedPortName;
  int _baudRate = 9600;

  bool get isConnected => _port != null;
  String? get connectedPortName => _connectedPortName;
  int get baudRate => _baudRate;

  /// COM port names currently visible to the OS (e.g. ["COM3", "COM4"]).
  List<String> availablePorts() {
    if (!customerDisplaySupported) return const [];
    try {
      return platform.platformAvailablePorts();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> connect({required String portName, int baudRate = 9600}) async {
    if (!customerDisplaySupported) return false;
    disconnect();
    final opened = platform.platformOpen(portName, baudRate);
    if (opened == null) return false;
    _port = opened;
    _connectedPortName = portName;
    _baudRate = baudRate;
    return true;
  }

  void disconnect() {
    if (_port != null) {
      platform.platformClose(_port!);
    }
    _port = null;
    _connectedPortName = null;
  }

  void _write(Uint8List bytes) {
    final port = _port;
    if (port == null) return;
    try {
      platform.platformWrite(port, bytes);
    } catch (_) {
      // A write failing usually means the device was unplugged - drop the
      // handle so isConnected reflects reality instead of a stale port.
      disconnect();
    }
  }

  /// Clears the display (ESC @ - standard ESC/POS initialize).
  void clear() {
    _write(Uint8List.fromList([0x1B, 0x40]));
  }

  /// Writes two lines of plain text. Most 2-line ESC/POS pole displays
  /// treat a carriage return as "move to line 2, clear rest of that line",
  /// and re-clearing (ESC @) first prevents stale characters from a longer
  /// previous line bleeding through on a shorter one.
  void showLines(String line1, String line2) {
    clear();
    final buffer = BytesBuilder();
    buffer.add(ascii.encode(_sanitizeForDisplay(line1)));
    buffer.addByte(0x0D); // CR -> line 2
    buffer.add(ascii.encode(_sanitizeForDisplay(line2)));
    _write(buffer.toBytes());
  }

  /// The actual feature this was built for: show the final sale total to
  /// the customer once checkout completes.
  void showTotal(double amount, {String currencySymbol = ''}) {
    final formatted = _formatAmount(amount, currencySymbol);
    showLines('TOTAL DUE', formatted);
  }

  /// Reverts the display to an idle greeting once a receipt has been handed
  /// over, so it doesn't keep showing a stale total for the next customer.
  void showIdle({String message = 'THANK YOU'}) {
    showLines(message, '');
  }

  String _formatAmount(double amount, String currencySymbol) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final wholeDigits = parts[0].replaceFirst('-', '');
    final buffer = StringBuffer();
    for (var i = 0; i < wholeDigits.length; i++) {
      if (i > 0 && (wholeDigits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholeDigits[i]);
    }
    final sign = amount < 0 ? '-' : '';
    final grouped = '$sign$buffer.${parts[1]}';
    return currencySymbol.isEmpty ? grouped : '$currencySymbol $grouped';
  }

  // ESC/POS text mode only supports plain ASCII reliably across these
  // clone displays - naira/other currency glyphs and smart quotes render as
  // garbage on the VFD, so they're stripped rather than sent through.
  String _sanitizeForDisplay(String input) {
    final buffer = StringBuffer();
    for (final code in input.codeUnits) {
      buffer.writeCharCode(code >= 0x20 && code <= 0x7E ? code : 0x20);
    }
    final result = buffer.toString().trimRight();
    return result.length > 20 ? result.substring(0, 20) : result;
  }

  // ── Local (per-device) settings persistence ──────────────────────────

  Future<CustomerDisplaySettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return CustomerDisplaySettings(
      enabled: prefs.getBool(_prefsKeyEnabled) ?? false,
      portName: prefs.getString(_prefsKeyPort),
      baudRate: prefs.getInt(_prefsKeyBaudRate) ?? 9600,
    );
  }

  Future<void> saveSettings(CustomerDisplaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, settings.enabled);
    if (settings.portName != null) {
      await prefs.setString(_prefsKeyPort, settings.portName!);
    } else {
      await prefs.remove(_prefsKeyPort);
    }
    await prefs.setInt(_prefsKeyBaudRate, settings.baudRate);
  }

  /// Connects using whatever was last saved, if the feature is enabled.
  /// Safe to call repeatedly (e.g. on every checkout) - it's a no-op once
  /// already connected to the same port.
  Future<void> ensureConnectedFromSavedSettings() async {
    if (!customerDisplaySupported) return;
    final settings = await loadSettings();
    if (!settings.enabled || settings.portName == null) return;
    if (isConnected && connectedPortName == settings.portName) return;
    await connect(portName: settings.portName!, baudRate: settings.baudRate);
  }
}

class CustomerDisplaySettings {
  final bool enabled;
  final String? portName;
  final int baudRate;

  const CustomerDisplaySettings({
    required this.enabled,
    required this.portName,
    required this.baudRate,
  });

  CustomerDisplaySettings copyWith({
    bool? enabled,
    String? portName,
    int? baudRate,
  }) {
    return CustomerDisplaySettings(
      enabled: enabled ?? this.enabled,
      portName: portName ?? this.portName,
      baudRate: baudRate ?? this.baudRate,
    );
  }
}
