import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key, required this.events});

  final List<Event> events;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  Set<int> _eventDaysInMonth() {
    final days = <int>{};
    for (final event in widget.events) {
      if (event.startDate.year == _currentMonth.year &&
          event.startDate.month == _currentMonth.month) {
        days.add(event.startDate.day);
      }
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month).weekday;
    final eventDays = _eventDaysInMonth();
    final today = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                onPressed: _nextMonth,
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: daysInMonth + firstWeekday - 1,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink();
              }

              final day = index - firstWeekday + 2;
              final hasEvent = eventDays.contains(day);
              final isToday = today.year == _currentMonth.year &&
                  today.month == _currentMonth.month &&
                  today.day == day;

              return GestureDetector(
                onTap: hasEvent
                    ? () {
                        final event = widget.events.firstWhere(
                          (e) =>
                              e.startDate.year == _currentMonth.year &&
                              e.startDate.month == _currentMonth.month &&
                              e.startDate.day == day,
                        );
                        context.go('/events/${event.id}');
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isToday ? AppColors.cyan.withValues(alpha: 0.2) : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: AppColors.cyan) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color:
                              isToday ? AppColors.cyan : AppColors.textPrimary,
                          fontWeight:
                              isToday ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                      if (hasEvent)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.cyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
