import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/session_provider.dart';
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

  /// The name the user set, or the one their identity provider supplied. Null
  /// only when neither exists — see [resolvedName] for what to actually show.
  final String? displayName;

  final String? avatarUrl;
  final DateTime? createdAt;

  /// The best name available for this user, never a generic placeholder.
  ///
  /// Falls back to the email's local part, tidied up: `carlos.perez@x.com`
  /// reads as "Carlos Perez". In almost every case that *is* the user's name,
  /// and it always beats labelling them "Navis User".
  String get resolvedName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return _nameFromEmail(email);
  }

  /// The avatar initial, from the same source as [resolvedName].
  String get initial {
    final name = resolvedName;
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }
}

/// Turns an email local part into a display name: separators become spaces,
/// digits and empty fragments are dropped, and each word is capitalised.
/// Returns the raw local part when that leaves nothing usable.
String _nameFromEmail(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return '';

  final words = local
      .split(RegExp(r'[._\-+]+'))
      .map((word) => word.replaceAll(RegExp(r'\d'), '').trim())
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .toList();

  return words.isEmpty ? local : words.join(' ');
}

/// Reads the display name out of Supabase user metadata.
///
/// Which key holds it depends on how the user signed up: a name set in-app
/// lands in `display_name`, OAuth providers write `full_name` or `name`, and
/// Apple may supply only the parts. Checking a single key meant every email
/// signup fell through to the placeholder.
String? displayNameFromMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;

  for (final key in ['display_name', 'full_name', 'name', 'preferred_name']) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }

  final given = metadata['given_name'] ?? metadata['first_name'];
  final family = metadata['family_name'] ?? metadata['last_name'];
  final parts = [given, family]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);
  if (parts.isNotEmpty) return parts.join(' ');

  return null;
}

final profileProvider = Provider<UserProfile?>((ref) {
  ref.watch(sessionUserIdProvider);
  final user = supabaseClient.auth.currentUser;
  if (user == null) return null;

  final metadata = user.userMetadata;
  return UserProfile(
    id: user.id,
    email: user.email ?? '',
    displayName: displayNameFromMetadata(metadata),
    avatarUrl: metadata?['avatar_url'] as String?,
    createdAt: DateTime.tryParse(user.createdAt),
  );
});
