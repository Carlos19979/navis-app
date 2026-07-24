import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/session_provider.dart';
import 'package:navis_mobile/features/moderation/data/repositories/moderation_repository.dart';

/// Repository for content reports and user blocks.
final moderationRepositoryProvider =
    Provider<ModerationRepository>((ref) => ModerationRepository());

/// The set of user IDs the current user has blocked. Re-runs on account switch.
/// The client hides content from these users; the server also filters discovery.
final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(sessionUserIdProvider);
  return ref.watch(moderationRepositoryProvider).blockedUserIds();
});
