import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/app/router.dart';
import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/database/sync_auth_listener.dart';
import 'package:navis_mobile/core/deeplinks/auth_deep_link.dart';
import 'package:navis_mobile/core/deeplinks/join_deep_link.dart';
import 'package:navis_mobile/core/lifecycle/background_copy.dart';
import 'package:navis_mobile/core/theme/app_theme.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_auth_listener.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_offline_banner.dart';

class NavisApp extends ConsumerWidget {
  const NavisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationAuthListenerProvider);
    ref.watch(billingAuthListenerProvider);
    ref.watch(syncAuthListenerProvider);
    ref.watch(joinDeepLinkListenerProvider);
    ref.watch(authDeepLinkListenerProvider);
    ref.watch(mutationQueueProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Navis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      routerConfig: router,
      builder: (context, child) {
        // Dates: here, not in main(), because this is where the locale
        // MaterialApp actually resolved is readable — `localeProvider` is null
        // when the user follows the system, and Settings can change it at
        // runtime.
        NavisDateUtils.useLocale(Localizations.localeOf(context));
        // Same reason, same place: the trip recorder and the anchor watch put
        // text in the notification shade while no screen exists to translate
        // it. Null-tolerant because a missing string must never take the whole
        // app down.
        final l = AppLocalizations.of(context);
        if (l != null) BackgroundCopy.useLocalizations(l);
        return NavisOfflineBanner(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
