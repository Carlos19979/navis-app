import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

String _localizedBoatType(AppLocalizations l, String type) => switch (type) {
      'sailboat' => l.sailboat,
      'motorboat' => l.motorboat,
      'catamaran' => l.catamaran,
      'other' => l.other,
      _ => type[0].toUpperCase() + type.substring(1),
    };

class BoatDetailScreen extends ConsumerWidget {
  const BoatDetailScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final boatAsync = ref.watch(boatProvider(boatId));

    return boatAsync.when(
      loading: () => const GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: NavisLoading(),
        ),
      ),
      error: (error, stack) => GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: NavisAppBar(title: l.boat, showBack: true),
          body: NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(boatProvider(boatId)),
          ),
        ),
      ),
      data: (boat) => _BoatDetailView(boat: boat),
    );
  }
}

class _BoatDetailView extends ConsumerWidget {
  const _BoatDetailView({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            _BoatSliverAppBar(boat: boat),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _InfoSection(boat: boat)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),
                  if (boat.isOwner) ...[
                    _ActionTile(
                      icon: Icons.description_outlined,
                      title: l.documents,
                      subtitle: l.certificates,
                      color: AppColors.cyan,
                      onTap: () => context.push('/boats/${boat.id}/documents'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.route_outlined,
                      title: l.logbook,
                      subtitle: l.tripHistory,
                      color: AppColors.green,
                      onTap: () => context.push('/boats/${boat.id}/trips'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.build_outlined,
                      title: 'Mantenimiento y gastos',
                      subtitle: 'Servicios y costes del barco',
                      color: AppColors.amber,
                      onTap: () =>
                          context.push('/boats/${boat.id}/maintenance'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.people_outline,
                      title: 'Compartir barco',
                      subtitle: 'Tripulación y copropietarios',
                      color: AppColors.cyan,
                      onTap: () => _shareBoat(context, ref, boat),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      title: l.editBoat,
                      subtitle: l.modifyBoatDetails,
                      color: AppColors.amber,
                      onTap: () => context.push('/boats/${boat.id}/edit'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.delete_outlined,
                      title: l.deleteBoat,
                      subtitle: l.removePermanently,
                      color: AppColors.red,
                      onTap: () => _confirmDelete(context, ref),
                    ),
                  ] else ...[
                    NavisCard(
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_outlined,
                              color: AppColors.cyan),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Barco compartido contigo. Tienes los permisos '
                              'que te haya dado el propietario.',
                              style: TextStyle(color: context.txtSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (boat.permissions.canViewDocuments) ...[
                      _ActionTile(
                        icon: Icons.description_outlined,
                        title: l.documents,
                        subtitle: l.certificates,
                        color: AppColors.cyan,
                        onTap: () =>
                            context.push('/boats/${boat.id}/documents'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _ActionTile(
                      icon: Icons.route_outlined,
                      title: l.logbook,
                      subtitle: l.tripHistory,
                      color: AppColors.green,
                      onTap: () => context.push('/boats/${boat.id}/trips'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.build_outlined,
                      title: 'Mantenimiento y gastos',
                      subtitle: 'Servicios y costes del barco',
                      color: AppColors.amber,
                      onTap: () =>
                          context.push('/boats/${boat.id}/maintenance'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.logout,
                      title: 'Salir del barco compartido',
                      subtitle: 'Dejar de tener acceso',
                      color: AppColors.red,
                      onTap: () => _leaveBoat(context, ref, boat),
                    ),
                  ],
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dialogSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: context.glassBorderColor,
            width: 0.5,
          ),
        ),
        title: Text(l.deleteBoat),
        content: Text(l.deleteBoatConfirm(boat.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(boatsProvider.notifier).deleteBoat(boat.id);
                if (context.mounted) {
                  context.go('/boats');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l.failedToDelete}: $e'),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _shareBoat(
      BuildContext context, WidgetRef ref, Boat boat) async {
    final messenger = ScaffoldMessenger.of(context);
    String code;
    try {
      code = await ref.read(boatShareRepositoryProvider).shareCode(boat.id);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el código')),
      );
      return;
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.dialogSurface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compartir barco',
                style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Comparte este código. Quien lo introduzca verá el barco. '
              'Activa "puede grabar viajes" abajo para darle permiso de editor.',
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.4), width: 0.5),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Código copiado')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.cyan),
                    onPressed: () => Share.share(
                        'Únete a mi barco "${boat.name}" en Navis con el '
                        'código: $code'),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Con acceso',
                style: TextStyle(
                    color: context.txtPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final membersAsync = ref.watch(boatMembersProvider(boat.id));
                return membersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Text('Error: $e',
                      style: TextStyle(color: context.txtSecondary)),
                  data: (members) {
                    if (members.isEmpty) {
                      return Text('Aún no has compartido con nadie.',
                          style: TextStyle(color: context.txtSecondary));
                    }
                    return Column(
                      children: [
                        for (final m in members)
                          _MemberPermissionsTile(boatId: boat.id, member: m),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveBoat(
      BuildContext context, WidgetRef ref, Boat boat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dialogSurfaceElevated,
        title: const Text('Salir del barco'),
        content: Text('Dejarás de tener acceso a "${boat.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(boatShareRepositoryProvider).leaveBoat(boat.id);
    ref.invalidate(sharedBoatsProvider);
    if (context.mounted) context.go('/boats');
  }
}

class _BoatSliverAppBar extends StatelessWidget {
  const _BoatSliverAppBar({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.deepNavy,
      foregroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.white,
          ),
          tooltip: AppLocalizations.of(context)!.goBack,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/boats');
            }
          },
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          boat.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 12,
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (boat.photoUrl != null && boat.photoUrl!.isNotEmpty)
              Semantics(
                label: AppLocalizations.of(context)!.boatPhoto,
                child: CachedNetworkImage(
                  imageUrl: boat.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.darkCard,
                  ),
                  errorWidget: (context, url, error) => _placeholderImage(),
                ),
              )
            else
              _placeholderImage(),
            // Improved 3-stop gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.teal],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.sailing,
          size: 64,
          color: AppColors.cyan.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.details,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.tag,
            label: AppLocalizations.of(context)!.registration,
            value: boat.registration,
          ),
          _glassDivider(context),
          _DetailRow(
            icon: Icons.category_outlined,
            label: AppLocalizations.of(context)!.type,
            value: _localizedBoatType(AppLocalizations.of(context)!, boat.type),
          ),
          _glassDivider(context),
          _DetailRow(
            icon: Icons.straighten,
            label: AppLocalizations.of(context)!.length,
            value: '${boat.lengthMeters} m',
          ),
          if (boat.homePort != null) ...[
            _glassDivider(context),
            _DetailRow(
              icon: Icons.anchor,
              label: AppLocalizations.of(context)!.homePort,
              value: boat.homePort!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _glassDivider(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: context.glassBorderColor,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.cyan),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.txtSecondary,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.txtSecondary,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.txtSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

/// A shared member with a per-permission toggle editor (owner-facing).
class _MemberPermissionsTile extends ConsumerStatefulWidget {
  const _MemberPermissionsTile({required this.boatId, required this.member});

  final String boatId;
  final BoatMember member;

  @override
  ConsumerState<_MemberPermissionsTile> createState() =>
      _MemberPermissionsTileState();
}

class _MemberPermissionsTileState
    extends ConsumerState<_MemberPermissionsTile> {
  late BoatPermissions _perms = widget.member.permissions;

  Future<void> _update(BoatPermissions next) async {
    setState(() => _perms = next);
    await ref
        .read(boatShareRepositoryProvider)
        .setMemberPermissions(widget.boatId, widget.member.userId, next);
    ref.invalidate(boatMembersProvider(widget.boatId));
  }

  Widget _toggle(
      String label, bool value, BoatPermissions Function(bool) apply) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      activeThumbColor: AppColors.cyan,
      title: Text(label,
          style: TextStyle(color: context.txtPrimary, fontSize: 13)),
      value: value,
      onChanged: (v) => _update(apply(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final granted = [
      _perms.canRecordTrips,
      _perms.canManageExpenses,
      _perms.canManageMaintenance,
      _perms.canViewDocuments,
      _perms.canManageDocuments,
    ].where((e) => e).length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
        leading: const Icon(Icons.person_outline),
        title: Text(widget.member.name,
            style: TextStyle(color: context.txtPrimary)),
        subtitle: Text('$granted ${granted == 1 ? 'permiso' : 'permisos'}',
            style: TextStyle(color: context.txtSecondary, fontSize: 12)),
        children: [
          _toggle('Grabar viajes', _perms.canRecordTrips,
              (v) => _perms.copyWith(canRecordTrips: v)),
          _toggle('Gestionar gastos', _perms.canManageExpenses,
              (v) => _perms.copyWith(canManageExpenses: v)),
          _toggle('Gestionar mantenimiento', _perms.canManageMaintenance,
              (v) => _perms.copyWith(canManageMaintenance: v)),
          _toggle('Ver documentos', _perms.canViewDocuments,
              (v) => _perms.copyWith(canViewDocuments: v)),
          _toggle('Gestionar documentos', _perms.canManageDocuments,
              (v) => _perms.copyWith(canManageDocuments: v)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await ref
                    .read(boatShareRepositoryProvider)
                    .removeMember(widget.boatId, widget.member.userId);
                ref.invalidate(boatMembersProvider(widget.boatId));
              },
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppColors.red, size: 18),
              label: const Text('Quitar acceso',
                  style: TextStyle(color: AppColors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
