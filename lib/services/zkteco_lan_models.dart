class ZktecoLanConnectionResult {
  const ZktecoLanConnectionResult({
    required this.connected,
    required this.message,
    this.serialNumber,
    this.deviceName,
    this.deviceTime,
    this.os,
    this.version,
  });

  final bool connected;
  final String message;
  final String? serialNumber;
  final String? deviceName;
  final DateTime? deviceTime;
  final String? os;
  final String? version;
}

class ZktecoLanUser {
  const ZktecoLanUser({
    this.uid,
    required this.userId,
    required this.name,
    required this.role,
    this.password,
    this.cardNo,
  });

  final int? uid;
  final String userId;
  final String name;
  final String role;
  final String? password;
  final int? cardNo;
}

class ZktecoLanAttendanceLog {
  const ZktecoLanAttendanceLog({
    this.uid,
    required this.userId,
    required this.timestamp,
    this.state,
    this.type,
  });

  final int? uid;
  final String userId;
  final DateTime? timestamp;
  final int? state;
  final int? type;
}

