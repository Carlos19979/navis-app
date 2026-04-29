import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/network/notification_service.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const NavisAppBar(title: 'Profile', showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                        color:
                            AppColors.cyan.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.darkSurfaceElevated,
                    child: Text(
                      (profile.displayName ?? profile.email)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 16),

                Text(
                  profile.displayName ?? 'Navis User',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ).animate().fadeIn(
                      duration: 400.ms,
                      delay: 100.ms,
                    ),

                const SizedBox(height: 4),

                Text(
                  profile.email,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ).animate().fadeIn(
                      duration: 400.ms,
                      delay: 150.ms,
                    ),

                if (profile.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Member since ${NavisDateUtils.formatDate(profile.createdAt!)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.7),
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
                        title: 'Settings',
                        onTap: () => context.push('/settings'),
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.glassBorder
                            .withValues(alpha: 0.3),
                        indent: 56,
                      ),
                      _ProfileTile(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {},
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.glassBorder
                            .withValues(alpha: 0.3),
                        indent: 56,
                      ),
                      _ProfileTile(
                        icon: Icons.info_outline,
                        title: 'About Navis',
                        onTap: () {},
                      ),
                    ],
                  ),
                ).animate().fadeIn(
                      duration: 400.ms,
                      delay: 250.ms,
                    ).slideY(
                      begin: 0.05,
                      end: 0,
                      duration: 400.ms,
                      delay: 250.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 24),

                // Logout button
                NavisButton(
                  label: 'Log Out',
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final notificationService =
                  ref.read(notificationServiceProvider);
              await notificationService.unregisterDevice();
              await ref.read(authProvider.notifier).logout();
              if (ctx.mounted) {
                context.go('/login');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
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
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
