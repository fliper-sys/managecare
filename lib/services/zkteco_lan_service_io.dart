import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';

import 'zkteco_lan_models.dart';

class ZktecoLanService {
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ZKTecoLAN] $message');
    }
  }

  ZKTeco _device({
    required String ipAddress,
    required int port,
    required Duration timeout,
    String? password,
  }) {
    final trimmedPassword = password?.trim();
    return ZKTeco(
      ipAddress,
      port: port,
      timeout: timeout,
      tcp: true,
      debug: false,
      password:
          trimmedPassword == null || trimmedPassword.isEmpty ? null : trimmedPassword,
    );
  }

  Future<ZktecoLanConnectionResult> testConnection({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 8),
    bool omitPing = true,
  }) async {
    final normalizedIp = _normalizeIpv4Address(ipAddress);
    if (normalizedIp == null) {
      return ZktecoLanConnectionResult(
        connected: false,
        message: 'Invalid terminal LAN IP address: $ipAddress.',
      );
    }
    _log(
      'testConnection start ip=$normalizedIp port=$port timeout=${timeout.inSeconds}s omitPing=$omitPing passwordSet=${password?.trim().isNotEmpty == true}',
    );
    final socketMessage = await _checkTcpSocket(normalizedIp, port, timeout);
    if (socketMessage != null) {
      _log('testConnection socket failed: $socketMessage');
      return ZktecoLanConnectionResult(
        connected: false,
        message: socketMessage,
      );
    }

    final device = _device(
      ipAddress: normalizedIp,
      port: port,
      timeout: timeout,
      password: password,
    );

    try {
      _log('testConnection socket ok; starting ZKTeco handshake');
      final connected = await device.connect(ommitPing: omitPing);
      _log('testConnection handshake result=$connected');
      if (!connected) {
        return ZktecoLanConnectionResult(
          connected: false,
          message: 'Could not connect to $normalizedIp:$port.',
        );
      }

      final serial = await _safeString(device.serialNumber);
      _log('testConnection serial=${serial ?? '-'}');
      final name = await _safeString(device.getDeviceName);
      _log('testConnection deviceName=${name ?? '-'}');
      final os = await _safeString(device.getOS);
      final version = await _safeString(device.version);
      DateTime? time;
      try {
        time = await device.getTime();
        _log('testConnection deviceTime=$time');
      } catch (_) {
        _log('testConnection deviceTime unavailable');
        time = null;
      }

      return ZktecoLanConnectionResult(
        connected: true,
        message: 'Connected to $normalizedIp:$port.',
        serialNumber: serial,
        deviceName: name,
        deviceTime: time,
        os: os,
        version: version,
      );
    } catch (error) {
      _log('testConnection handshake error=$error');
      return ZktecoLanConnectionResult(
        connected: false,
        message:
            'TCP socket opened, but ZKTeco handshake failed: $error. Confirm the terminal communication password, port, and that the device supports LAN SDK access.',
      );
    } finally {
      await _disconnectQuietly(device);
      _log('testConnection done');
    }
  }

  Future<List<ZktecoLanUser>> getUsers({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 12),
    bool omitPing = true,
  }) async {
    final normalizedIp = _normalizeIpv4Address(ipAddress);
    if (normalizedIp == null) {
      throw FormatException('Invalid terminal LAN IP address: $ipAddress.');
    }
    _log(
      'getUsers start ip=$normalizedIp port=$port timeout=${timeout.inSeconds}s omitPing=$omitPing passwordSet=${password?.trim().isNotEmpty == true}',
    );
    final socketMessage = await _checkTcpSocket(normalizedIp, port, timeout);
    if (socketMessage != null) {
      _log('getUsers socket failed: $socketMessage');
      throw TimeoutException(socketMessage, timeout);
    }

    final device = _device(
      ipAddress: normalizedIp,
      port: port,
      timeout: timeout,
      password: password,
    );

    try {
      _log('getUsers socket ok; starting ZKTeco handshake');
      final connected = await device.connect(ommitPing: omitPing);
      _log('getUsers handshake result=$connected');
      if (!connected) return const <ZktecoLanUser>[];
      final users = await device.getUsers();
      final mappedUsers = users.map(_mapUser).toList();
      _log('getUsers returned count=${mappedUsers.length}');
      for (final user in mappedUsers.take(5)) {
        _log('getUsers sample userId=${user.userId} name=${user.name} role=${user.role}');
      }
      return mappedUsers;
    } finally {
      await _disconnectQuietly(device);
      _log('getUsers done');
    }
  }

  Future<List<ZktecoLanAttendanceLog>> getAttendanceLogs({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 20),
    bool omitPing = true,
  }) async {
    final normalizedIp = _normalizeIpv4Address(ipAddress);
    if (normalizedIp == null) {
      throw FormatException('Invalid terminal LAN IP address: $ipAddress.');
    }
    _log(
      'getAttendanceLogs start ip=$normalizedIp port=$port timeout=${timeout.inSeconds}s omitPing=$omitPing passwordSet=${password?.trim().isNotEmpty == true}',
    );
    final socketMessage = await _checkTcpSocket(normalizedIp, port, timeout);
    if (socketMessage != null) {
      _log('getAttendanceLogs socket failed: $socketMessage');
      throw TimeoutException(socketMessage, timeout);
    }

    final device = _device(
      ipAddress: normalizedIp,
      port: port,
      timeout: timeout,
      password: password,
    );

    try {
      _log('getAttendanceLogs socket ok; starting ZKTeco handshake');
      final connected = await device.connect(ommitPing: omitPing);
      _log('getAttendanceLogs handshake result=$connected');
      if (!connected) return const <ZktecoLanAttendanceLog>[];
      final logs = await device.getAttendanceLogs();
      final mappedLogs = logs.map(_mapAttendanceLog).toList();
      _log('getAttendanceLogs returned count=${mappedLogs.length}');
      for (final log in mappedLogs.take(5)) {
        _log(
          'getAttendanceLogs sample userId=${log.userId} timestamp=${log.timestamp} state=${log.state} type=${log.type}',
        );
      }
      return mappedLogs;
    } finally {
      await _disconnectQuietly(device);
      _log('getAttendanceLogs done');
    }
  }

  ZktecoLanUser _mapUser(UserInfo user) {
    return ZktecoLanUser(
      uid: user.uid,
      userId: user.userId ?? '',
      name: user.name ?? '',
      role: user.role == UserType.admin ? 'admin' : 'user',
      password: user.password,
      cardNo: user.cardNo,
    );
  }

  ZktecoLanAttendanceLog _mapAttendanceLog(AttendanceLog log) {
    return ZktecoLanAttendanceLog(
      uid: log.uid,
      userId: log.id ?? '',
      timestamp: log.timestamp,
      state: log.state,
      type: log.type,
    );
  }

  Future<String?> _safeString(Future<dynamic> Function() call) async {
    try {
      final value = await call();
      return value?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _disconnectQuietly(ZKTeco device) async {
    try {
      await device.disconnect();
      _log('disconnect ok');
    } catch (_) {
      _log('disconnect skipped/failed');
      // Best effort cleanup after a LAN operation.
    }
  }

  String? _normalizeIpv4Address(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4) return null;

    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      octets.add(octet);
    }

    return octets.join('.');
  }

  Future<String?> _checkTcpSocket(
    String ipAddress,
    int port,
    Duration timeout,
  ) async {
    Socket? socket;
    try {
      _log('socket check start $ipAddress:$port');
      socket = await Socket.connect(ipAddress, port, timeout: timeout);
      _log('socket check ok local=${socket.address.address}:${socket.port}');
      return null;
    } on TimeoutException {
      _log('socket check timeout $ipAddress:$port');
      return 'Connection timed out reaching $ipAddress:$port. Confirm the app device is on the same LAN/WiFi as the terminal, the terminal IP is correct, and Port No is open.';
    } on SocketException catch (error) {
      _log('socket check socket exception $ipAddress:$port ${error.message}');
      return 'Cannot reach $ipAddress:$port: ${error.message}. Check the terminal LAN IP, Port No, WiFi isolation, firewall, and that the device is powered on.';
    } catch (error) {
      _log('socket check error $ipAddress:$port $error');
      return 'Cannot reach $ipAddress:$port: $error';
    } finally {
      socket?.destroy();
      _log('socket check closed $ipAddress:$port');
    }
  }
}
