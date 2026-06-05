import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final expiryAlerts = ref.watch(expiryAlertsProvider);
    final eventReminders = ref.watch(eventRemindersProvider);

    final languageLabel = switch (locale?.languageCode) {
      'es' => 'Español',
      'en' => 'English',
      _ => l.systemDefault,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(title: l.settings, showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      label: l.appearance.toUpperCase(),
                    ),
                    SwitchListTile(
                      title: Text(l.darkMode),
                      subtitle: Text(
                        themeMode == ThemeMode.dark
                            ? l.darkThemeActive
                            : l.lightThemeActive,
                      ),
                      value: themeMode == ThemeMode.dark,
                      activeTrackColor: AppColors.cyan.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.cyan,
                      onChanged: (value) {
                        ref.read(themeModeProvider.notifier).set(
                              value ? ThemeMode.dark : ThemeMode.light,
                            );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      label: l.language.toUpperCase(),
                    ),
                    ListTile(
                      title: Text(l.language),
                      subtitle: Text(languageLabel),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: context.txtSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () => _showLanguagePicker(
                        context,
                        ref,
                        locale,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      label: l.notifications.toUpperCase(),
                    ),
                    SwitchListTile(
                      title: Text(l.documentExpiryAlerts),
                      subtitle: Text(l.expiryAlertsSubtitle),
                      value: expiryAlerts,
                      activeTrackColor: AppColors.cyan.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.cyan,
                      onChanged: (value) {
                        ref.read(expiryAlertsProvider.notifier).set(value);
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.glassBorderColor.withValues(alpha: 0.3),
                      indent: 16,
                      endIndent: 16,
                    ),
                    SwitchListTile(
                      title: Text(l.eventReminders),
                      subtitle: Text(l.eventRemindersSubtitle),
                      value: eventReminders,
                      activeTrackColor: AppColors.cyan.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.cyan,
                      onChanged: (value) {
                        ref.read(eventRemindersProvider.notifier).set(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      label: l.dataAndStorage.toUpperCase(),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.cached,
                        color: context.txtSecondary,
                      ),
                      title: Text(l.clearImageCache),
                      subtitle: Text(l.clearImageCacheSubtitle),
                      onTap: () async {
                        await CachedNetworkImage.evictFromCache('');
                        await DefaultCacheManager().emptyCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l.imageCacheCleared),
                            ),
                          );
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.glassBorderColor.withValues(alpha: 0.3),
                      indent: 56,
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_sweep,
                        color: context.txtSecondary,
                      ),
                      title: Text(l.clearOfflineData),
                      subtitle: Text(l.clearOfflineDataSubtitle),
                      onTap: () async {
                        final db = ref.read(localDatabaseProvider);
                        await db.clearTable('boats');
                        await db.clearTable('documents');
                        await db.clearTable('trips');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l.offlineDataCleared),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NavisCard(
                padding: EdgeInsets.zero,
                borderColor: AppColors.red.withValues(alpha: 0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      label: l.account.toUpperCase(),
                      color: AppColors.red.withValues(alpha: 0.8),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: NavisButton(
                        label: l.logout,
                        icon: Icons.logout,
                        variant: NavisButtonVariant.danger,
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l.logout),
                              content: Text(l.logoutConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.red,
                                  ),
                                  child: Text(l.logout),
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

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    Locale? currentLocale,
  ) {
    final l = AppLocalizations.of(context)!;
    final currentCode = currentLocale?.languageCode;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(l.selectLanguage),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: l.systemDefault,
              selected: currentCode == null,
              onTap: () {
                ref.read(localeProvider.notifier).set(null);
                Navigator.pop(ctx);
              },
            ),
            _LanguageOption(
              label: 'English',
              flag: '🇬🇧',
              selected: currentCode == 'en',
              onTap: () {
                ref.read(localeProvider.notifier).set(const Locale('en'));
                Navigator.pop(ctx);
              },
            ),
            _LanguageOption(
              label: 'Español',
              flag: '🇪🇸',
              selected: currentCode == 'es',
              onTap: () {
                ref.read(localeProvider.notifier).set(const Locale('es'));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.color = AppColors.cyan,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    this.flag,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: flag != null
          ? Text(
              flag!,
              style: const TextStyle(fontSize: 24),
            )
          : Icon(
              Icons.phone_android,
              color: context.txtSecondary,
            ),
      title: Text(label),
      trailing: selected
          ? const Icon(
              Icons.check_circle,
              color: AppColors.cyan,
            )
          : null,
      onTap: onTap,
    );
  }
}
