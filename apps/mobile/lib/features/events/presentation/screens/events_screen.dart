import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/widgets/calendar_view.dart';
import 'package:navis_mobile/features/events/presentation/widgets/event_card.dart';
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
      filtered = filtered
          .where((e) => e.eventType == _selectedType)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((e) =>
              e.name.toLowerCase().contains(_searchQuery) ||
              e.locationName
                  .toLowerCase()
                  .contains(_searchQuery) ||
              e.organizer
                  .toLowerCase()
                  .contains(_searchQuery))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: NavisAppBar(
        title: 'Events',
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.list : Icons.calendar_month,
            ),
            tooltip: 'Toggle view',
            onPressed: () {
              setState(() => _showCalendar = !_showCalendar);
            },
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () =>
            const NavisShimmer(itemCount: 4, itemHeight: 100),
        error: (error, stack) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(eventsProvider),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const NavisEmptyState(
              icon: Icons.event_outlined,
              message: 'No upcoming events.',
            );
          }

          final filtered = _applyFilters(events);

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(
                                  () => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  children: _eventTypes.entries.map((entry) {
                    final isSelected =
                        _selectedType == entry.key;
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.value),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() =>
                              _selectedType = entry.key);
                        },
                        selectedColor: AppColors.cyan
                            .withValues(alpha: 0.2),
                        checkmarkColor: AppColors.cyan,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.cyan
                              : AppColors.textSecondary
                                  .withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              if (_showCalendar)
                Expanded(
                  child: CalendarView(events: filtered),
                )
              else
                Expanded(
                  child: filtered.isEmpty
                      ? const NavisEmptyState(
                          icon: Icons.search_off,
                          message:
                              'No events match your search.',
                        )
                      : RefreshIndicator(
                          color: AppColors.cyan,
                          onRefresh: () async {
                            ref.invalidate(eventsProvider);
                          },
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return EventCard(
                                event: filtered[index],
                              );
                            },
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}
