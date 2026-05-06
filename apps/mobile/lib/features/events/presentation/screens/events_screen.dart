import 'dart:async';

import 'package:navis_mobile/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/widgets/calendar_view.dart';
import 'package:navis_mobile/features/events/presentation/widgets/event_card.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

const _eventTypes = {
  'all': 'All',
  'regatta': 'Regatta',
  'cruise': 'Cruise',
  'meetup': 'Meetup',
  'exhibition': 'Exhibition',
  'course': 'Course',
  'other': 'Other',
};

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  bool _showCalendar = false;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String _selectedType = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value.toLowerCase());
    });
  }

  List<Event> _applyFilters(List<Event> events) {
    var filtered = events;

    if (_selectedType != 'all') {
      filtered = filtered.where((e) => e.eventType == _selectedType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((e) =>
              e.name.toLowerCase().contains(_searchQuery) ||
              e.locationName.toLowerCase().contains(_searchQuery) ||
              e.organizer.toLowerCase().contains(_searchQuery))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: l.events,
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.list : Icons.calendar_month,
              color: AppColors.textPrimary,
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
              if (events.isEmpty) {
                return NavisEmptyState(
                  icon: Icons.event_outlined,
                  message: l.noEvents,
                );
              }

              final filtered = _applyFilters(events);

              return Column(
                children: [
                  // Glass search field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: l.searchEvents,
                          hintStyle: TextStyle(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppColors.textSecondary,
                                  ),
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Glass filter pills
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _eventTypes.entries.map((entry) {
                        final isSelected = _selectedType == entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedType = entry.key);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    isSelected ? AppColors.cyanGradient : null,
                                color: isSelected ? null : AppColors.glassWhite,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.cyan.withValues(alpha: 0.6)
                                      : AppColors.glassBorder,
                                  width: isSelected ? 1 : 0.5,
                                ),
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Calendar or list view
                  if (_showCalendar)
                    Expanded(
                      child: CalendarView(events: filtered),
                    )
                  else
                    Expanded(
                      child: filtered.isEmpty
                          ? NavisEmptyState(
                              icon: Icons.search_off,
                              message: l.noEventsFound,
                            )
                          : RefreshIndicator(
                              color: AppColors.cyan,
                              backgroundColor: AppColors.darkSurface,
                              onRefresh: () async {
                                ref.invalidate(eventsProvider);
                              },
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  return EventCard(
                                    event: filtered[index],
                                  )
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
                            ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
