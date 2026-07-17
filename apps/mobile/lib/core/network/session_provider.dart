import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';

/// The current session's user id, kept in sync with Supabase auth events.
///
/// User-scoped long-lived providers (boat list, account, shared boats…)
/// `ref.watch` this so their caches are rebuilt when the signed-in user
/// changes — without it, logging into another account on the same app
/// instance showed the previous user's cached data until a manual refresh.
final sessionUserIdProvider =
    NotifierProvider<SessionUserIdNotifier, String?>(SessionUserIdNotifier.new);

class SessionUserIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    try {
      final sub = supabaseClient.auth.onAuthStateChange.listen((event) {
        final id = event.session?.user.id;
        if (id != state) state = id;
      });
      ref.onDispose(sub.cancel);
      return supabaseClient.auth.currentSession?.user.id;
    } catch (_) {
      // Supabase not initialized (pure widget/provider tests): behave as
      // signed-out and never notify — the watchers just don't rebuild.
      return null;
    }
  }
}
