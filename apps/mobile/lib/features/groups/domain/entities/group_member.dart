/// A user's membership in a group.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    required this.status,
    this.name = '',
    this.joinedAt,
  });

  final String userId;
  final String name;
  final String role; // 'owner' | 'member'
  final String status; // 'pending' | 'active'
  final DateTime? joinedAt;

  bool get isOwner => role == 'owner';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
