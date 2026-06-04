import 'package:navis_mobile/features/groups/domain/entities/group.dart';

class GroupModel {
  const GroupModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.visibility,
    this.description,
    this.photoUrl,
    this.inviteCode,
    this.memberCount = 0,
    this.pendingCount = 0,
    this.myMembershipStatus = 'none',
    this.myRole = '',
    this.createdAt,
    this.updatedAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      visibility: json['visibility'] as String,
      inviteCode: json['invite_code'] as String?,
      memberCount: json['member_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      myMembershipStatus: json['my_membership_status'] as String? ?? 'none',
      myRole: json['my_role'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? photoUrl;
  final String visibility;
  final String? inviteCode;
  final int memberCount;
  final int pendingCount;
  final String myMembershipStatus;
  final String myRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Group toEntity() => Group(
        id: id,
        ownerId: ownerId,
        name: name,
        description: description,
        photoUrl: photoUrl,
        visibility: visibility,
        inviteCode: inviteCode,
        memberCount: memberCount,
        pendingCount: pendingCount,
        myMembershipStatus: myMembershipStatus,
        myRole: myRole,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
