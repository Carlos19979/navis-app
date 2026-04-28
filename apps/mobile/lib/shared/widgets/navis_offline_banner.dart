import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/connectivity_provider.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class NavisOfflineBanner extends ConsumerWidget {
  const NavisOfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isOnline ? 0 : 32,
          color: AppColors.amber,
          child: isOnline
              ? const SizedBox.shrink()
              : Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.noInternetConnection ??
                            'No internet connection',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
