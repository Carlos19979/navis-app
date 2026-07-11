import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Shown after signup while the confirmation email is pending. The user has no
/// session yet; confirming the link and logging in completes registration.
class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key});

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  bool _resending = false;

  Future<void> _resend() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendConfirmationEmail();
      if (mounted) NavisSnackbar.success(context, l.emailResent);
    } catch (_) {
      if (mounted) NavisSnackbar.error(context, l.couldNotResend);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final email = ref.watch(authProvider).pendingEmail ?? '';

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 72,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.checkEmailTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.checkEmailBody(email),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.txtSecondary),
                  ),
                  const SizedBox(height: 32),
                  NavisButton(
                    label: l.resendEmail,
                    icon: Icons.send,
                    isLoading: _resending,
                    onPressed: _resend,
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).backToLogin();
                      context.go('/login');
                    },
                    child: Text(
                      l.backToLogin,
                      style: TextStyle(color: context.txtSecondary),
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
