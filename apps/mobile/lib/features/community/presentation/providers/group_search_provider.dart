import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';

/// Shortest query the public-group search accepts, mirroring the server
/// (`GroupService.SearchPublic`) and the port search: one character would turn
/// into a `%a%` scan of every public group.
const int groupSearchMinChars = 2;

/// Server-side name search over discoverable public groups.
///
/// Returns an empty list for blank/too-short queries without hitting the
/// network, so the field can be wired straight to the provider. autoDispose so
/// leaving the Discover tab releases the results instead of caching a query the
/// user has moved on from.
final groupSearchProvider =
    FutureProvider.autoDispose.family<List<Group>, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.length < groupSearchMinChars) return const [];
  final repo = ref.watch(groupRepositoryProvider);
  final response = await repo.getGroups(discover: true, query: trimmed);
  return response.items;
});
