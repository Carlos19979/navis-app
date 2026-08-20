import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/config/checklist_preference.dart';
import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/byte_utils.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/charts/presentation/providers/offline_charts_provider.dart';
import 'package:navis_mobile/features/notifications/presentation/widgets/notification_preferences_card.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/features/profile/presentation/widgets/export_data_tile.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
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
    final checklistMode = ref.watch(preTripChecklistModeProvider);
    final chartBytes = ref.watch(chartStorageBytesProvider).valueOrNull;

    final languageLabel = switch (locale?.languageCode) {
      'es' => 'Español',
      'en' => 'English',
      _ => l.systemDefault,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: NavisAppBar(title: l.settings, showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Dev-only plan switcher (debug builds only). In production the
              // plan is driven by the RevenueCat purchase/webhook flow.
              if (kDebugMode) ...[
                NavisCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(label: 'PLAN (PRUEBAS)'),
                      Consumer(
                        builder: (context, ref, _) {
                          final current =
                              ref.watch(accountProvider).valueOrNull?.plan ??
                                  'free';
                          Widget tile(String value, String label, String sub) {
                            return ListTile(
                              title: Text(label),
                              subtitle: Text(sub),
                              trailing: current == value
                                  ? Icon(Icons.check_circle,
                                      color: context.accent)
                                  : null,
                              onTap: () async {
                                if (current == value) return;
                                try {
                                  await ref
                                      .read(accountRepositoryProvider)
                                      .setPlan(value);
                                  ref.invalidate(accountProvider);
                                  if (context.mounted) {
                                    NavisSnackbar.success(
                                        context, 'Plan cambiado a $label');
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    NavisSnackbar.error(
                                        context, 'No se pudo cambiar el plan');
                                  }
                                }
                              },
                            );
                          }

                          return Column(
                            children: [
                              tile('free', 'Free', '1 barco · básico'),
                              tile('plus', 'Plus',
                                  '2 barcos · alarma fondeo · readiness'),
                              tile('pro', 'Pro',
                                  '3 barcos · costes · splits · pasaporte'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                      activeTrackColor: context.accent.withValues(alpha: 0.5),
                      activeThumbColor: context.accent,
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
              // Server-backed, one switch per notification category. The two
              // switches that used to be here wrote only to local preferences
              // that nothing read, so they promised control they did not have.
              const NotificationPreferencesCard(),
              const SizedBox(height: 12),
              // The way back for anyone who chose "skip" (and remembered it)
              // when starting a trip: without this the pre-trip checklist would
              // be gone for good.
              NavisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(label: l.safetyChecklist.toUpperCase()),
                    SwitchListTile(
                      title: Text(l.preTripChecklistSetting),
                      subtitle: Text(switch (checklistMode) {
                        PreTripChecklistMode.ask => l.preTripChecklistAsks,
                        PreTripChecklistMode.review => l.preTripChecklistAlways,
                        PreTripChecklistMode.skip => l.preTripChecklistSkipped,
                      }),
                      value: checklistMode != PreTripChecklistMode.skip,
                      activeTrackColor: context.accent.withValues(alpha: 0.5),
                      activeThumbColor: context.accent,
                      onChanged: (value) {
                        ref.read(preTripChecklistModeProvider.notifier).set(
                              value
                                  ? PreTripChecklistMode.ask
                                  : PreTripChecklistMode.skip,
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
                      label: l.dataAndStorage.toUpperCase(),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.map_outlined,
                        color: context.txtSecondary,
                      ),
                      title: Text(l.offlineCharts),
                      subtitle: Text(
                        chartBytes == null
                            ? l.manageSavedAreas
                            : l.chartStorageUsed(
                                ByteUtils.format(chartBytes),
                              ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: context.txtSecondary,
                      ),
                      onTap: () => context.push(Routes.offlineCharts),
                    ),
                    Divider(
                      height: 1,
                      color: context.glassBorderColor.withValues(alpha: 0.3),
                      indent: 56,
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
                    Divider(
                      height: 1,
                      color: context.glassBorderColor.withValues(alpha: 0.3),
                      indent: 56,
                    ),
                    const ExportDataTile(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NavisCard(
                padding: EdgeInsets.zero,
                borderColor: context.critical.withValues(alpha: 0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      label: l.account.toUpperCase(),
                      color: context.critical.withValues(alpha: 0.8),
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
                                    foregroundColor: context.critical,
                                  ),
                                  child: Text(l.logout),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              context.go(Routes.login);
                            }
                          }
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: context.glassBorderColor.withValues(alpha: 0.3),
                      indent: 16,
                      endIndent: 16,
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever,
                        color: context.critical,
                      ),
                      title: Text(
                        l.deleteAccount,
                        style: TextStyle(color: context.critical),
                      ),
                      subtitle: Text(l.deleteAccountSubtitle),
                      onTap: () => _confirmDeleteAccount(context, ref),
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

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmWord = l.deleteAccountConfirmWord;

    // Step 1: explain exactly what gets deleted.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAccount),
        content: Text(l.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.critical),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    // Step 2: type-to-confirm.
    final controller = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.deleteAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.deleteAccountTypeToConfirm(confirmWord)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(hintText: confirmWord),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: controller.text.trim() == confirmWord
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: TextButton.styleFrom(foregroundColor: context.critical),
              child: Text(l.delete),
            ),
          ],
        ),
      ),
    );
    if (typed != true || !context.mounted) return;

    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
    } catch (_) {
      if (context.mounted) {
        NavisSnackbar.error(context, l.deleteAccountFailed);
      }
      return;
    }

    // Clear local state: cached rows and the (now invalid) session.
    final db = ref.read(localDatabaseProvider);
    await db.clearTable('boats');
    await db.clearTable('documents');
    await db.clearTable('trips');
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      // The auth user no longer exists server-side; the local session is
      // stale either way, so proceed to login.
    }
    if (context.mounted) {
      context.go(Routes.login);
    }
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
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: NavisType.overline.copyWith(color: color ?? context.inkMuted),
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
          ? Icon(
              Icons.check_circle,
              color: context.accent,
            )
          : null,
      onTap: onTap,
    );
  }
}
