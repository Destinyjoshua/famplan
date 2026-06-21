import 'package:famplan/data/models/family_plan.dart';
import 'package:famplan/data/models/profile.dart';

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.timezone,
    this.inviteCode,
    this.inviteCodeExpiresAt,
    required this.createdBy,
    required this.createdAt,
    required this.subscription,
  });

  final String id;
  final String name;
  final String timezone;
  final String? inviteCode;
  final DateTime? inviteCodeExpiresAt;
  final String createdBy;
  final DateTime createdAt;
  final FamilySubscription subscription;

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String,
      name: json['name'] as String,
      timezone: json['timezone'] as String? ?? 'UTC',
      inviteCode: json['invite_code'] as String?,
      inviteCodeExpiresAt: json['invite_code_expires_at'] != null
          ? DateTime.parse(json['invite_code_expires_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      subscription: FamilySubscription.fromFamilyJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'timezone': timezone,
        'invite_code': inviteCode,
        'invite_code_expires_at': inviteCodeExpiresAt?.toIso8601String(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'plan_id': subscription.planId,
        'plan_status': subscription.planStatus,
        'plan_started_at': subscription.planStartedAt?.toIso8601String(),
        'plan_expires_at': subscription.planExpiresAt?.toIso8601String(),
      };
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
    this.profile,
  });

  final String id;
  final String familyId;
  final String userId;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final Profile? profile;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      profile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'user_id': userId,
        'role': role,
        'status': status,
        'joined_at': joinedAt?.toIso8601String(),
      };

  bool get isAdmin => role == 'admin';

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'child':
        return 'Child';
      default:
        return 'Member';
    }
  }
}
