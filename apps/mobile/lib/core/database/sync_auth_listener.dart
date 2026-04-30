import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/database/sync_service.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';

final syncAuthListenerProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);

  if (authState.status == AuthStatus.authenticated) {
    ref.read(syncServiceProvider).syncAll();
  }
});
