import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/network/connectivity_provider.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class NavisOfflineBanner extends ConsumerWidget {
  const NavisOfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final pendingCount = ref.watch(mutationQueueProvider);
    final l10n = AppLocalizations.of(context);
    final showBanner = !isOnline || pendingCount > 0;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: showBanner ? 32 : 0,
          color: isOnline ? AppColors.cyan : AppColors.amber,
          child: showBanner
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOnline ? Icons.sync : Icons.cloud_off,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _bannerText(
                          isOnline: isOnline,
                          pendingCount: pendingCount,
                          l10n: l10n,
                        ),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }

  String _bannerText({
    required bool isOnline,
    required int pendingCount,
    required AppLocalizations? l10n,
  }) {
    if (!isOnline && pendingCount > 0) {
      return l10n?.offlineWithPending(pendingCount) ??
          'Offline \u2022 $pendingCount pending';
    }
    if (!isOnline) {
      return l10n?.noInternetConnection ?? 'No internet connection';
    }
    return l10n?.syncingChanges(pendingCount) ??
        'Syncing $pendingCount changes\u2026';
  }
}
