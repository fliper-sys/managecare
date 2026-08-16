// Copyright 2026 Manage Care. All rights reserved.
// Use of this source code is governed by an Apache 2.0 license
// that can be found in the LICENSE file.

// Real serial-port implementation, compiled in on every non-web platform
// (see the conditional import in customer_display_service.dart). Actual use
// is further restricted to Windows at the CustomerDisplayService level -
// flutter_libserialport's native library isn't bundled for mobile, and this
// feature is a Windows POS-terminal peripheral, not a phone one.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

bool platformIsSupported() =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

List<String> platformAvailablePorts() {
  try {
    return SerialPort.availablePorts;
  } catch (_) {
    return const [];
  }
}

Object? platformOpen(String portName, int baudRate) {
  try {
    final port = SerialPort(portName);
    if (!port.openReadWrite()) {
      port.dispose();
      return null;
    }
    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);
    port.config = config;
    config.dispose();
    return port;
  } catch (_) {
    return null;
  }
}

void platformClose(Object port) {
  if (port is SerialPort) {
    try {
      port.close();
    } catch (_) {}
    try {
      port.dispose();
    } catch (_) {}
  }
}

void platformWrite(Object port, Uint8List bytes) {
  if (port is SerialPort) {
    port.write(bytes);
  }
}
