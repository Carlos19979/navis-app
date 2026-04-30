import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const NavisAppBar(title: 'Settings', showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Appearance section
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'APPEARANCE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use dark theme'),
                      value: isDarkMode,
                      activeTrackColor: AppColors.cyan.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.cyan,
                      onChanged: (value) {
                        ref.read(themeModeProvider.notifier).state = value;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Language section
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'LANGUAGE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Language'),
                      subtitle: const Text('English'),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Notifications section
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'NOTIFICATIONS',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Document Expiry Alerts'),
                      subtitle:
                          const Text('Get notified before documents expire'),
                      value: true,
                      activeTrackColor: AppColors.cyan.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.cyan,
                      onChanged: (value) {},
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.glassBorder.withValues(alpha: 0.3),
                      indent: 16,
                      endIndent: 16,
                    ),
                    SwitchListTile(
                      title: const Text('Event Reminders'),
                      subtitle:
                          const Text('Get reminded about upcoming events'),
                      value: true,
                      activeTrackColor: AppColors.cyan.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.cyan,
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Data & Storage section
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'DATA & STORAGE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cached,
                          color: AppColors.textSecondary),
                      title: const Text('Clear Image Cache'),
                      subtitle:
                          const Text('Remove cached photos and map tiles'),
                      onTap: () async {
                        await CachedNetworkImage.evictFromCache('');
                        await DefaultCacheManager().emptyCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Image cache cleared')),
                          );
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.glassBorder.withValues(alpha: 0.3),
                      indent: 56,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep,
                          color: AppColors.textSecondary),
                      title: const Text('Clear Offline Data'),
                      subtitle:
                          const Text('Remove cached boats, documents, trips'),
                      onTap: () async {
                        final db = ref.read(localDatabaseProvider);
                        await db.clearTable('boats');
                        await db.clearTable('documents');
                        await db.clearTable('trips');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Offline data cleared')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Danger zone
              NavisCard(
                padding: EdgeInsets.zero,
                borderColor: AppColors.red.withValues(alpha: 0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'ACCOUNT',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.red.withValues(alpha: 0.8),
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: NavisButton(
                        label: 'Log Out',
                        icon: Icons.logout,
                        variant: NavisButtonVariant.danger,
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Log Out'),
                              content: const Text(
                                  'Are you sure you want to log out?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.red,
                                  ),
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
