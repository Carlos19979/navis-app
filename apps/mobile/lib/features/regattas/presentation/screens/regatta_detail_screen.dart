import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

const _statusLabels = {
  'planned': 'Programada',
  'recording': 'En curso',
  'completed': 'Completada',
  'cancelled': 'Cancelada',
};

const _statusColors = {
  'planned': AppColors.cyan,
  'recording': AppColors.green,
  'completed': AppColors.textSecondary,
  'cancelled': AppColors.red,
};

class RegattaDetailScreen extends ConsumerWidget {
  const RegattaDetailScreen({required this.regattaId, super.key});

  final String regattaId;

  String get _uid => supabaseClient.auth.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(regattaProvider(regattaId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: async.valueOrNull?.displayTitle ?? 'Regata',
        showBack: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const NavisLoading(),
            error: (e, _) => NavisErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(regattaProvider(regattaId)),
            ),
            data: (regatta) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _summary(context, regatta),
                const SizedBox(height: 16),
                Text('¿Vas a ir?',
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _RsvpRow(regattaId: regattaId, currentUserId: _uid),
                const SizedBox(height: 16),
                _Participants(regattaId: regattaId),
                if (regatta.groupId != null) ...[
                  const SizedBox(height: 16),
                  _MemberRsvpList(
                    regattaId: regattaId,
                    groupId: regatta.groupId!,
                  ),
                ],
                const SizedBox(height: 24),
                if (regatta.ownerId == _uid)
                  _ownerControls(context, ref, regatta),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, Regatta r) {
    final color = _statusColors[r.status] ?? context.txtSecondary;
    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.displayTitle,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabels[r.status] ?? r.status,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row(context, Icons.place, r.departurePort),
          if (r.scheduledAt != null)
            _row(context, Icons.event,
                NavisDateUtils.formatDateTime(r.scheduledAt!)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.txtSecondary),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: context.txtSecondary)),
        ],
      ),
    );
  }

  Widget _ownerControls(BuildContext context, WidgetRef ref, Regatta r) {
    if (r.isPlanned) {
      return Column(
        children: [
          NavisButton(
            label: 'Preparar checklist y zarpar',
            icon: Icons.checklist,
            onPressed: () => context.push(
              '/trips/${r.id}/checklist?groupId=${r.groupId ?? ''}',
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.red),
            label: const Text('Cancelar regata',
                style: TextStyle(color: AppColors.red)),
            onPressed: () => _cancel(context, ref, r),
          ),
        ],
      );
    }
    if (r.isRecording) {
      return NavisCard(
        child: Row(
          children: [
            const Icon(Icons.sailing, color: AppColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text('La regata está en curso (grabando).',
                  style: TextStyle(color: context.txtPrimary)),
            ),
          ],
        ),
      );
    }
    // Completed or cancelled: the owner can delete it permanently.
    if (r.status == 'completed' || r.status == 'cancelled') {
      return NavisButton(
        label: 'Eliminar regata',
        icon: Icons.delete_outline,
        variant: NavisButtonVariant.danger,
        onPressed: () => _delete(context, ref, r),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Regatta r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.dialogSurface,
        title: Text('Eliminar regata', style: TextStyle(color: ctx.txtPrimary)),
        content: Text(
          'Se eliminará esta regata de forma permanente.',
          style: TextStyle(color: ctx.txtSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(regattaRepositoryProvider).delete(r.id);
      if (r.groupId != null) {
        ref.invalidate(groupRegattasProvider(r.groupId!));
      }
      if (!context.mounted) return;
      NavisSnackbar.success(context, 'Regata eliminada');
      context.pop();
    } catch (_) {
      if (!context.mounted) return;
      NavisSnackbar.error(context, 'No se pudo eliminar');
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Regatta r) async {
    try {
      await ref.read(regattaRepositoryProvider).cancel(r.id);
      ref.invalidate(regattaProvider(regattaId));
      if (r.groupId != null) {
        ref.invalidate(groupRegattasProvider(r.groupId!));
      }
      if (!context.mounted) return;
      NavisSnackbar.success(context, 'Regata cancelada');
    } catch (_) {
      if (!context.mounted) return;
      NavisSnackbar.error(context, 'No se pudo cancelar');
    }
  }
}

class _RsvpRow extends ConsumerWidget {
  const _RsvpRow({required this.regattaId, required this.currentUserId});

  final String regattaId;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(regattaParticipantsProvider(regattaId));
    final mine = participants.valueOrNull
        ?.where((p) => p.userId == currentUserId)
        .toList();
    final myRsvp = (mine != null && mine.isNotEmpty) ? mine.first.rsvp : null;

    Widget pill(String value, String label, IconData icon, Color color) {
      final selected = myRsvp == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () async {
              try {
                await ref
                    .read(regattaRepositoryProvider)
                    .setRsvp(regattaId, value);
                ref.invalidate(regattaParticipantsProvider(regattaId));
              } catch (_) {
                if (!context.mounted) return;
                NavisSnackbar.error(context, 'No se pudo responder');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:
                    selected ? color.withValues(alpha: 0.2) : context.glassBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : context.glassBorderColor,
                  width: selected ? 1 : 0.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon,
                      color: selected ? color : context.txtSecondary, size: 20),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          color: selected ? color : context.txtSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('going', 'Voy', Icons.check_circle, AppColors.green),
        pill('maybe', 'Quizá', Icons.help_outline, AppColors.amber),
        pill('not_going', 'No voy', Icons.cancel, AppColors.red),
      ],
    );
  }
}

class _Participants extends ConsumerWidget {
  const _Participants({required this.regattaId});

  final String regattaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(regattaParticipantsProvider(regattaId));
    return async.maybeWhen(
      data: (participants) {
        final going = participants.where((p) => p.rsvp == 'going').length;
        final maybe = participants.where((p) => p.rsvp == 'maybe').length;
        final notGoing =
            participants.where((p) => p.rsvp == 'not_going').length;
        return NavisCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _count(context, 'Van', going, AppColors.green),
              _count(context, 'Quizá', maybe, AppColors.amber),
              _count(context, 'No van', notGoing, AppColors.red),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _count(BuildContext context, String label, int n, Color color) {
    return Column(
      children: [
        Text('$n',
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label,
            style: TextStyle(color: context.txtSecondary, fontSize: 12)),
      ],
    );
  }
}

/// Lists every group member with their RSVP status for the regatta.
class _MemberRsvpList extends ConsumerWidget {
  const _MemberRsvpList({required this.regattaId, required this.groupId});

  final String regattaId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final participants =
        ref.watch(regattaParticipantsProvider(regattaId)).valueOrNull ??
            const [];
    final rsvpByUser = <String, String>{
      for (final p in participants) p.userId: p.rsvp,
    };

    return membersAsync.maybeWhen(
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();
        return NavisCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Miembros',
                  style: TextStyle(
                      color: context.txtPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (var i = 0; i < members.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: context.glassBorderColor.withValues(alpha: 0.3),
                  ),
                _MemberRow(
                  name:
                      members[i].name.isNotEmpty ? members[i].name : 'Miembro',
                  isOwner: members[i].role == 'owner',
                  rsvp: rsvpByUser[members[i].userId],
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.isOwner,
    required this.rsvp,
  });

  final String name;
  final bool isOwner;
  final String? rsvp;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (rsvp) {
      'going' => (AppColors.green, Icons.check_circle),
      'maybe' => (AppColors.amber, Icons.help_outline),
      'not_going' => (AppColors.red, Icons.cancel),
      _ => (context.txtSecondary, Icons.remove_circle_outline),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.cyan, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(color: context.txtPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star, size: 13, color: AppColors.amber),
                ],
              ],
            ),
          ),
          Icon(icon, size: 20, color: color),
        ],
      ),
    );
  }
}
