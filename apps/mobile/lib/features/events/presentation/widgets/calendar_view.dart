import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

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
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month).weekday;
    final eventDays = _eventDaysInMonth();
    final today = DateTime.now();

    final weekdayNames = List.generate(7, (i) {
      final date = DateTime(2024, 1, i + 1); // 2024-01-01 is a Monday
      return DateFormat.E(locale).format(date);
    });

    return Column(
      children: [
        // Month header in glass card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: NavisCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  tooltip: l.previousMonth,
                  icon: Icon(
                    Icons.chevron_left,
                    color: context.txtPrimary,
                  ),
                ),
                Text(
                  DateFormat.yMMMM(locale).format(_currentMonth),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  tooltip: l.nextMonth,
                  icon: Icon(
                    Icons.chevron_right,
                    color: context.txtPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdayNames
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.txtSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Day grid
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isToday
                        ? null
                        : hasEvent
                            ? context.glassBg
                            : Colors.transparent,
                    gradient: isToday ? AppColors.cyanGradient : null,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday
                        ? Border.all(
                            color: AppColors.cyan,
                            width: 1.5,
                          )
                        : hasEvent
                            ? Border.all(
                                color: context.glassBorderColor,
                                width: 0.5,
                              )
                            : null,
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isToday
                              ? Colors.white
                              : hasEvent
                                  ? context.txtPrimary
                                  : context.txtSecondary,
                          fontWeight: isToday || hasEvent
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                      if (hasEvent)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isToday ? Colors.white : AppColors.cyan,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isToday ? Colors.white : AppColors.cyan)
                                    .withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
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
}
