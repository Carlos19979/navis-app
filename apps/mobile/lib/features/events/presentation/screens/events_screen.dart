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

/// Thin standalone wrapper around [EventsBody] (kept for direct use/tests).
/// In the app it is hosted inside the Community tab via [EventsBody].
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: NavisAppBar(title: l.events),
      body: const GradientBackground(
        child: SafeArea(bottom: false, child: EventsBody()),
      ),
    );
  }
}

/// Body-only regattas feed, with an internal list/calendar toggle. Composed by
/// both [EventsScreen] and the Community tab.
class EventsBody extends ConsumerStatefulWidget {
  const EventsBody({super.key});

  @override
  ConsumerState<EventsBody> createState() => _EventsBodyState();
}

class _EventsBodyState extends ConsumerState<EventsBody> {
  bool _showCalendar = false;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final l = AppLocalizations.of(context)!;

    return eventsAsync.when(
      loading: () => const NavisShimmer(itemCount: 4, itemHeight: 100),
      error: (error, stack) => NavisErrorWidget(
        message: error.toString(),
        onRetry: () => ref.invalidate(eventsProvider),
      ),
      data: (events) {
        // Only regattas for now.
        final regattas = events.where((e) => e.eventType == 'regatta').toList(
              growable: false,
            );

        if (regattas.isEmpty) {
          return NavisEmptyState(
            icon: Icons.event_outlined,
            message: l.noEvents,
          );
        }

        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: IconButton(
                  icon: Icon(
                    _showCalendar
                        ? Icons.view_list_rounded
                        : Icons.calendar_month,
                    color: context.txtSecondary,
                  ),
                  tooltip: _showCalendar ? l.communityRegattas : l.eventDate,
                  onPressed: () =>
                      setState(() => _showCalendar = !_showCalendar),
                ),
              ),
            ),
            Expanded(
              child: _showCalendar
                  ? CalendarView(events: regattas)
                  : RefreshIndicator(
                      color: AppColors.cyan,
                      backgroundColor: context.dialogSurface,
                      onRefresh: () async => ref.invalidate(eventsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        itemCount: regattas.length,
                        itemBuilder: (context, index) {
                          return EventCard(event: regattas[index])
                              .animate()
                              .fadeIn(delay: (index * 60).ms, duration: 400.ms)
                              .slideY(
                                begin: 0.05,
                                end: 0,
                                delay: (index * 60).ms,
                                duration: 400.ms,
                                curve: Curves.easeOut,
                              );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
