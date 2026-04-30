import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_provider.dart';

/// Watches auth state and initializes/tears down push notifications accordingly.
/// Must be watched from the app root (e.g. NavisApp) to stay active.
final notificationAuthListenerProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);

  if (authState.status == AuthStatus.authenticated) {
    ref.read(notificationProvider.notifier).initialize();
  } else if (authState.status == AuthStatus.unauthenticated) {
    ref.read(notificationProvider.notifier).unregister();
  }
});
