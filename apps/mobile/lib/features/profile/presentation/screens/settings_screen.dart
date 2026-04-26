import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: const NavisAppBar(title: 'Settings', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.cyan,
                        ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use dark theme'),
                  value: isDarkMode,
                  activeColor: AppColors.cyan,
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).state = value;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Language',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.cyan,
                        ),
                  ),
                ),
                ListTile(
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.cyan,
                        ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Document Expiry Alerts'),
                  subtitle: const Text('Get notified before documents expire'),
                  value: true,
                  activeColor: AppColors.cyan,
                  onChanged: (value) {},
                ),
                SwitchListTile(
                  title: const Text('Event Reminders'),
                  subtitle: const Text('Get reminded about upcoming events'),
                  value: true,
                  activeColor: AppColors.cyan,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
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
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
