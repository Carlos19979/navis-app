/// A club or crew. Public groups are join-by-request (owner approval); private
/// groups are joined with an invite code.
class Group {
  const Group({
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

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? photoUrl;
  final String visibility; // 'public' | 'private'
  final String? inviteCode; // only present for the owner
  final int memberCount;
  final int pendingCount;
  final String myMembershipStatus; // 'none' | 'pending' | 'active'
  final String myRole; // '' | 'owner' | 'member'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublic => visibility == 'public';
  bool get isOwner => myRole == 'owner';
  bool get isActiveMember => myMembershipStatus == 'active';
  bool get isPending => myMembershipStatus == 'pending';

  Group copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? photoUrl,
    String? visibility,
    String? inviteCode,
    int? memberCount,
    int? pendingCount,
    String? myMembershipStatus,
    String? myRole,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      visibility: visibility ?? this.visibility,
      inviteCode: inviteCode ?? this.inviteCode,
      memberCount: memberCount ?? this.memberCount,
      pendingCount: pendingCount ?? this.pendingCount,
      myMembershipStatus: myMembershipStatus ?? this.myMembershipStatus,
      myRole: myRole ?? this.myRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
