/// Maps a notification's `{type, id}` deep-link pair to an app route.
///
/// Shared by the two ways a notification is opened: tapping the system push
/// (`NotificationNotifier`) and tapping a row in the in-app feed. Returns null
/// when there is no target, or when the type is one this build cannot route
/// (a newer server may send a type an older app does not know).
String? notificationPath(String? type, String? id) {
  if (type == null || id == null || id.isEmpty) return null;

  return switch (type) {
    'document' => '/documents/$id',
    'regatta' => '/regattas/$id',
    'group' => '/groups/$id',
    'event' => '/events/$id',
    'trip' => '/trips/$id',
    'boat' => '/boats/$id',
    _ => null,
  };
}
