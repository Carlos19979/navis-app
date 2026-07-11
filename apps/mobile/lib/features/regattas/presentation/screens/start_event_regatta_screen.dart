import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Joins an event as one of the owner's groups: pick a group and a boat, which
/// creates a group regatta (pre-filled from the event). The regatta then lives
/// in Groups → group → Regattas with member RSVP, checklist, etc.
class StartEventRegattaScreen extends ConsumerStatefulWidget {
  const StartEventRegattaScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<StartEventRegattaScreen> createState() =>
      _StartEventRegattaScreenState();
}

class _StartEventRegattaScreenState
    extends ConsumerState<StartEventRegattaScreen> {
  String? _groupId;
  String? _boatId;
  bool _saving = false;

  Boat? _boatById(List<Boat> boats) {
    for (final b in boats) {
      if (b.id == _boatId) return b;
    }
    return null;
  }

  Future<void> _join(List<Boat> boats) async {
    final l = AppLocalizations.of(context)!;
    if (_groupId == null) {
      NavisSnackbar.error(context, l.selectAGroup);
      return;
    }
    if (_boatId == null) {
      NavisSnackbar.error(context, l.selectABoat);
      return;
    }

    final event = ref.read(eventProvider(widget.eventId)).valueOrNull;
    final boat = _boatById(boats);
    final departurePort = (boat?.homePort != null && boat!.homePort!.isNotEmpty)
        ? boat.homePort!
        : (event?.locationName ?? 'Puerto de salida');

    setState(() => _saving = true);
    try {
      final regatta = await ref.read(regattaRepositoryProvider).schedule(
            groupId: _groupId!,
            boatId: _boatId!,
            departurePort: departurePort,
            title: event?.name,
            scheduledAt: event?.startDate,
          );
      ref.invalidate(groupRegattasProvider(_groupId!));
      if (!mounted) return;
      NavisSnackbar.success(context, l.joinedWithGroup);
      context.pushReplacement('/regattas/${regatta.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NavisSnackbar.error(context, l.couldNotJoin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final groupsAsync = ref.watch(myGroupsProvider);
    final boatsAsync = ref.watch(boatsProvider);
    final boats = boatsAsync.valueOrNull ?? const <Boat>[];
    final eventName =
        ref.watch(eventProvider(widget.eventId)).valueOrNull?.name;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(title: l.joinAsGroup, showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (eventName != null) ...[
                NavisCard(
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: AppColors.cyan),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          eventName,
                          style: TextStyle(
                            color: context.txtPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _Label(l.groupLabel),
              const SizedBox(height: 8),
              groupsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.cyan)),
                error: (e, _) => Text(l.errorWithMessage(e.toString()),
                    style: const TextStyle(color: AppColors.red)),
                data: (groups) {
                  final owned =
                      groups.where((g) => g.isOwner).toList(growable: false);
                  if (owned.isEmpty) {
                    return Text(
                      l.createGroupFirst,
                      style: TextStyle(color: context.txtSecondary),
                    );
                  }
                  return Column(
                    children: owned
                        .map((g) => _SelectableCard(
                              icon: Icons.groups,
                              label: g.name,
                              selected: _groupId == g.id,
                              onTap: () => setState(() => _groupId = g.id),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              _Label(l.boat),
              const SizedBox(height: 8),
              boatsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.cyan)),
                error: (e, _) => Text(l.errorWithMessage(e.toString()),
                    style: const TextStyle(color: AppColors.red)),
                data: (boats) {
                  if (boats.isEmpty) {
                    return Text(
                      l.addBoatFirst,
                      style: TextStyle(color: context.txtSecondary),
                    );
                  }
                  return Column(
                    children: boats
                        .map((b) => _SelectableCard(
                              icon: Icons.sailing,
                              label: b.name,
                              selected: _boatId == b.id,
                              onTap: () => setState(() => _boatId = b.id),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 28),
              NavisButton(
                label: l.joinWithMyGroup,
                icon: Icons.flag,
                isLoading: _saving,
                isDisabled: _saving,
                onPressed: () => _join(boats),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: selected ? AppColors.cyan : null,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: context.txtPrimary)),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.cyan, size: 20),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600),
    );
  }
}
