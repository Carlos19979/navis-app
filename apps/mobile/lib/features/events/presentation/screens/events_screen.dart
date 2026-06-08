import 'package:navis_mobile/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/widgets/calendar_view.dart';
import 'package:navis_mobile/features/events/presentation/widgets/event_card.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  bool _showCalendar = false;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: NavisAppBar(
        title: l.events,
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.list : Icons.calendar_month,
              color: context.txtPrimary,
            ),
            tooltip: 'Toggle view',
            onPressed: () {
              setState(() => _showCalendar = !_showCalendar);
            },
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: eventsAsync.when(
            loading: () => const NavisShimmer(itemCount: 4, itemHeight: 100),
            error: (error, stack) => NavisErrorWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(eventsProvider),
            ),
            data: (events) {
              // Only regattas for now.
              final regattas = events
                  .where((e) => e.eventType == 'regatta')
                  .toList(growable: false);

              if (regattas.isEmpty) {
                return NavisEmptyState(
                  icon: Icons.event_outlined,
                  message: l.noEvents,
                );
              }

              if (_showCalendar) {
                return CalendarView(events: regattas);
              }

              return RefreshIndicator(
                color: AppColors.cyan,
                backgroundColor: context.dialogSurface,
                onRefresh: () async {
                  ref.invalidate(eventsProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: regattas.length,
                  itemBuilder: (context, index) {
                    return EventCard(event: regattas[index])
                        .animate()
                        .fadeIn(
                          delay: (index * 60).ms,
                          duration: 400.ms,
                        )
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          delay: (index * 60).ms,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
