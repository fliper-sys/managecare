// lib/data/models/gym_member_model.dart

class Member {
  final String id;
  final String name;
  final String email;
  final String phone;
  DateTime joinedAt;
  bool active;
  String? membershipPlanId;
  DateTime? membershipExpiry;

  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    DateTime? joinedAt,
    this.active = true,
    this.membershipPlanId,
    this.membershipExpiry,
  }) : joinedAt = joinedAt ?? DateTime.now();

  Member copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    DateTime? joinedAt,
    bool? active,
    String? membershipPlanId,
    DateTime? membershipExpiry,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      joinedAt: joinedAt ?? this.joinedAt,
      active: active ?? this.active,
      membershipPlanId: membershipPlanId ?? this.membershipPlanId,
      membershipExpiry: membershipExpiry ?? this.membershipExpiry,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      try {
        final dyn = v as dynamic;
        return dyn.toDate();
      } catch (_) {
        return null;
      }
    }

    return Member(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      joinedAt: parseDate(json['joinedAt']) ?? DateTime.now(),
      active: json['active'] ?? true,
      membershipPlanId: json['membershipPlanId'] ?? json['membership_plan_id'],
      membershipExpiry:
          parseDate(json['membershipExpiry'] ?? json['membership_expiry']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'joinedAt': joinedAt.toIso8601String(),
      'active': active,
      'membershipPlanId': membershipPlanId,
      'membershipExpiry': membershipExpiry?.toIso8601String(),
    };
  }
}

