// Copyright 2026 Manage Care. All rights reserved.
// Use of this source code is governed by an Apache 2.0 license
// that can be found in the LICENSE file.

// Fallback used on web, where serial port access and dart:ffi don't exist.
// Every method is a safe no-op so CustomerDisplayService can be imported
// from shared code without a web build ever touching real port I/O.
import 'dart:typed_data';

bool platformIsSupported() => false;

List<String> platformAvailablePorts() => const [];

Object? platformOpen(String portName, int baudRate) => null;

void platformClose(Object port) {}

void platformWrite(Object port, Uint8List bytes) {}
