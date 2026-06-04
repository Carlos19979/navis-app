import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';

class GroupMemberModel {
  const GroupMemberModel({
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      userId: json['user_id'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
    );
  }

  final String userId;
  final String role;
  final String status;
  final DateTime? joinedAt;

  GroupMember toEntity() => GroupMember(
        userId: userId,
        role: role,
        status: status,
        joinedAt: joinedAt,
      );
}
