import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/groups/presentation/widgets/group_card.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _joinByCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Unirse por código',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Código de invitación',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => context.pop(controller.text.trim()),
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    try {
      final group = await ref.read(groupRepositoryProvider).joinByCode(code);
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      NavisSnackbar.success(context, 'Te has unido a ${group.name}');
    } catch (_) {
      if (!mounted) return;
      NavisSnackbar.error(context, 'Código inválido o error al unirse');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: 'Grupos',
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined,
                color: AppColors.textPrimary),
            tooltip: 'Unirse por código',
            onPressed: _joinByCode,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 124),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.cyanGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () => context.push('/groups/new'),
            tooltip: 'Crear grupo',
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              semanticLabel: 'Crear grupo',
            ),
          ),
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.cyan,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.cyan,
                tabs: const [
                  Tab(text: 'Mis grupos'),
                  Tab(text: 'Descubrir'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _GroupList(
                      provider: myGroupsProvider,
                      emptyIcon: Icons.groups_outlined,
                      emptyMessage: 'Aún no estás en ningún grupo.',
                      onTap: (g) => context.push('/groups/${g.id}'),
                    ),
                    _DiscoverList(),
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

class _GroupList extends ConsumerWidget {
  const _GroupList({
    required this.provider,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onTap,
    this.trailingBuilder,
  });

  final FutureProvider<List<Group>> provider;
  final IconData emptyIcon;
  final String emptyMessage;
  final void Function(Group) onTap;
  final Widget Function(Group)? trailingBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const NavisShimmer(itemCount: 4),
      error: (e, _) => NavisErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return NavisEmptyState(icon: emptyIcon, message: emptyMessage);
        }
        return RefreshIndicator(
          color: AppColors.cyan,
          backgroundColor: AppColors.darkSurface,
          onRefresh: () async => ref.invalidate(provider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            itemCount: groups.length,
            itemBuilder: (context, i) => GroupCard(
              group: groups[i],
              onTap: () => onTap(groups[i]),
              trailing: trailingBuilder?.call(groups[i]),
            ),
          ),
        );
      },
    );
  }
}

class _DiscoverList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _GroupList(
      provider: discoverGroupsProvider,
      emptyIcon: Icons.travel_explore_outlined,
      emptyMessage: 'No hay grupos públicos para descubrir.',
      onTap: (g) => context.push('/groups/${g.id}'),
      trailingBuilder: (g) => _JoinButton(group: g),
    );
  }
}

class _JoinButton extends ConsumerWidget {
  const _JoinButton({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (group.isPending) {
      return const Text(
        'Pendiente',
        style: TextStyle(color: AppColors.amber, fontSize: 13),
      );
    }
    return TextButton(
      onPressed: () async {
        try {
          await ref.read(groupRepositoryProvider).requestJoin(group.id);
          ref.invalidate(discoverGroupsProvider);
          if (!context.mounted) return;
          NavisSnackbar.success(context, 'Solicitud enviada');
        } catch (_) {
          if (!context.mounted) return;
          NavisSnackbar.error(context, 'No se pudo solicitar');
        }
      },
      child: const Text('Solicitar', style: TextStyle(color: AppColors.cyan)),
    );
  }
}
