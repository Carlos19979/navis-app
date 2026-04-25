import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
}

final profileProvider = Provider<UserProfile?>((ref) {
  final user = supabaseClient.auth.currentUser;
  if (user == null) return null;

  return UserProfile(
    id: user.id,
    email: user.email ?? '',
    displayName: user.userMetadata?['display_name'] as String?,
    avatarUrl: user.userMetadata?['avatar_url'] as String?,
    createdAt: DateTime.tryParse(user.createdAt),
  );
});

final themeModeProvider = StateProvider<bool>((ref) => true);
