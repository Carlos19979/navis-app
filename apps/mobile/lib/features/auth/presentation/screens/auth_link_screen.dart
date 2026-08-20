import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/deeplinks/auth_deep_link.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

/// Where the router lands when it is handed a location it has no route for.
///
/// In practice that means one thing: the `navis://login-callback` deep link an
/// auth email opens the app with. It carries a host and a query rather than a
/// path, so GoRouter matches nothing and used to render its bare "Page Not
/// Found" — which is exactly where password recovery died, one tap short of
/// working, with a valid session already in hand behind the error.
///
/// Almost nothing is decided here. supabase_flutter exchanges the code off the
/// same link, and the router's redirect moves us on to /reset-password or
/// /boats the moment it lands. This is the waiting room, plus the two exits
/// that would otherwise be dead ends: a link that already expired, and a wait
/// that never ends.
class AuthLinkScreen extends ConsumerStatefulWidget {
  const AuthLinkScreen({required this.uri, super.key});

  /// The location the router could not match — the incoming link itself.
  final Uri uri;

  /// How long to wait for the session before giving up and offering the way
  /// back. Generous: the exchange is a network round trip on a phone that may
  /// have just been woken by a notification.
  static const timeout = Duration(seconds: 12);

  @override
  ConsumerState<AuthLinkScreen> createState() => _AuthLinkScreenState();
}

class _AuthLinkScreenState extends ConsumerState<AuthLinkScreen> {
  Timer? _timer;
  late bool _failed = isFailedAuthUri(widget.uri);

  @override
  void initState() {
    super.initState();
    // Belt and braces with authDeepLinkListenerProvider: that one reads the
    // link from the plugin stream, this one from the location the router was
    // handed. Either alone is enough; both firing is idempotent, and between
    // them no platform can swallow the flag.
    if (!_failed && isPasswordRecoveryUri(widget.uri)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(passwordRecoveryProvider.notifier).begin();
        }
      });
    }
    if (!_failed) {
      _timer = Timer(AuthLinkScreen.timeout, () {
        if (mounted) setState(() => _failed = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link_off,
                          size: 56,
                          color: context.caution,
                          semanticLabel: l.authLinkExpiredTitle,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l.authLinkExpiredTitle,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge?.copyWith(
                            color: context.txtPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l.authLinkExpiredBody,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.txtSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        NavisButton(
                          label: l.backToLogin,
                          onPressed: () => context.go('/login'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: context.accent,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l.authLinkOpening,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.txtSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
