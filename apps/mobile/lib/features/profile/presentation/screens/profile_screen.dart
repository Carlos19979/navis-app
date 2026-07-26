import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:navis_mobile/core/config/env.dart';
import 'package:navis_mobile/core/network/notification_service.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profile = ref.watch(profileProvider);

    if (profile == null) {
      return Scaffold(
        body: Center(child: Text(l.notLoggedIn)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(title: l.profile, showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: Insets.screenWithNav,
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Avatar with gradient border ring
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.cyanGlowGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.darkSurfaceElevated,
                    child: Text(
                      profile.initial,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 16),

                // The user's own name — resolved from their metadata, or from
                // their email when signup never captured one. Tappable so they
                // can set or correct it.
                _EditableName(profile: profile).animate().fadeIn(
                      duration: 400.ms,
                      delay: 100.ms,
                    ),

                const SizedBox(height: 4),

                Text(
                  profile.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                      ),
                ).animate().fadeIn(
                      duration: 400.ms,
                      delay: 150.ms,
                    ),

                const SizedBox(height: 10),

                // Plan badge — tappable: below Pro it opens the paywall
                // (upgrade); on Pro it opens the store's manage-subscription
                // page (App Store / Play Store).
                Consumer(
                  builder: (context, ref, _) {
                    final account = ref.watch(accountProvider).valueOrNull;
                    if (account == null) return const SizedBox.shrink();
                    final tier = ref.watch(effectiveTierProvider);
                    return GestureDetector(
                      onTap: () {
                        if (tier == PlanTier.pro) {
                          _openManageSubscription(context, ref);
                        } else {
                          showPaywall(context, ref);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cyan.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Plan ${account.planLabel}',
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: AppColors.cyan,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ).animate().fadeIn(duration: 400.ms, delay: 180.ms),

                if (profile.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.memberSince(
                        NavisDateUtils.formatDate(profile.createdAt!)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.txtSecondary.withValues(alpha: 0.7),
                        ),
                  ).animate().fadeIn(
                        duration: 400.ms,
                        delay: 200.ms,
                      ),
                ],

                const SizedBox(height: 32),

                // Menu items in glass card
                NavisCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileTile(
                        icon: Icons.settings_outlined,
                        title: l.settings,
                        onTap: () => context.push('/settings'),
                      ),
                      Divider(
                        height: 1,
                        color: context.glassBorderColor.withValues(alpha: 0.3),
                        indent: 56,
                      ),
                      // Manage subscription — paid users only; opens the
                      // App Store / Play Store subscription page.
                      Consumer(
                        builder: (context, ref, _) {
                          final account =
                              ref.watch(accountProvider).valueOrNull;
                          if (account == null || account.plan == 'free') {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              _ProfileTile(
                                icon: Icons.workspace_premium_outlined,
                                title: l.manageSubscription,
                                onTap: () =>
                                    _openManageSubscription(context, ref),
                              ),
                              Divider(
                                height: 1,
                                color: context.glassBorderColor
                                    .withValues(alpha: 0.3),
                                indent: 56,
                              ),
                            ],
                          );
                        },
                      ),
                      _ProfileTile(
                        icon: Icons.help_outline,
                        title: l.helpAndSupport,
                        onTap: () => _launchExternal(
                          context,
                          Uri(scheme: 'mailto', path: Env.supportEmail),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: context.glassBorderColor.withValues(alpha: 0.3),
                        indent: 56,
                      ),
                      _ProfileTile(
                        icon: Icons.info_outline,
                        title: l.aboutNavis,
                        onTap: () => _showAbout(context),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: 400.ms,
                      delay: 250.ms,
                    )
                    .slideY(
                      begin: 0.05,
                      end: 0,
                      duration: 400.ms,
                      delay: 250.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 24),

                // Logout button
                NavisButton(
                  label: l.logout,
                  icon: Icons.logout,
                  variant: NavisButtonVariant.danger,
                  onPressed: () => _confirmLogout(context, ref),
                ).animate().fadeIn(
                      duration: 400.ms,
                      delay: 350.ms,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logout),
        content: Text(l.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final notificationService = ref.read(notificationServiceProvider);
              await notificationService.unregisterDevice();
              await ref.read(authProvider.notifier).logout();
              if (ctx.mounted) {
                context.go('/login');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: Text(l.logout),
          ),
        ],
      ),
    );
  }
}

/// The profile name, with a tap-to-edit affordance.
///
/// Email signup never captures a name, so for most users the name shown is
/// derived from their email until they set one here — which is also the only
/// place they can correct whatever their identity provider supplied.
class _EditableName extends ConsumerWidget {
  const _EditableName({required this.profile});

  final UserProfile profile;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final name = await NavisInputDialog.show(
      context,
      title: l.editNameTitle,
      hintText: l.yourName,
      initialValue: profile.displayName ?? profile.resolvedName,
      capitalization: TextCapitalization.words,
    );
    if (name == null || !context.mounted) return;
    try {
      await ref.read(authProvider.notifier).updateDisplayName(name);
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.somethingWentWrong);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l.editNameTitle,
      child: InkWell(
        onTap: () => _edit(context, ref),
        borderRadius: BorderRadius.circular(Dimens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spaceSm,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  profile.resolvedName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Dimens.spaceXs),
              Icon(
                Icons.edit_outlined,
                size: Dimens.iconSm,
                color: context.txtSecondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the store's subscription-management page (App Store / Play Store).
Future<void> _openManageSubscription(
    BuildContext context, WidgetRef ref) async {
  final uri = await ref.read(billingServiceProvider).managementUrl();
  if (uri == null || !context.mounted) return;
  await _launchExternal(context, uri);
}

Future<void> _launchExternal(BuildContext context, Uri uri) async {
  final l = AppLocalizations.of(context)!;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.couldNotOpenLink)));
  }
}

void _showAbout(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.aboutNavis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.aboutVersion(Env.appVersion)),
          const SizedBox(height: 8),
          Text(l.aboutDescription),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _launchExternal(ctx, Uri.parse(Env.privacyUrl)),
          child: Text(l.privacyPolicy),
        ),
        TextButton(
          onPressed: () => _launchExternal(ctx, Uri.parse(Env.termsUrl)),
          child: Text(l.termsOfService),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l.close),
        ),
      ],
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.txtSecondary),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right,
        color: context.txtSecondary.withValues(alpha: 0.5),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
