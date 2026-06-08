import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

/// Opens a bottom sheet with the hourly forecast for [day].
Future<void> showDayDetailSheet(BuildContext context, DailyWeather day) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DayDetailSheet(day: day),
  );
}

class DayDetailSheet extends ConsumerWidget {
  const DayDetailSheet({super.key, required this.day});

  final DailyWeather day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hourly = ref.watch(hourlyForDayProvider(day.date));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.dialogSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.txtSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _Header(day: day),
              Divider(
                height: 1,
                color: context.glassBorderColor.withValues(alpha: 0.4),
              ),
              Expanded(
                child: hourly.when(
                  loading: () => const NavisLoading(),
                  error: (error, _) => NavisErrorWidget(
                    message: error.toString(),
                    onRetry: () =>
                        ref.invalidate(hourlyForDayProvider(day.date)),
                  ),
                  data: (hours) {
                    if (hours.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)!.forecastNotAvailable,
                          style: TextStyle(color: context.txtSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: hours.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: context.glassBorderColor.withValues(alpha: 0.25),
                      ),
                      itemBuilder: (context, i) => _HourlyRow(hour: hours[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.day});

  final DailyWeather day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final condition = WeatherCondition.fromCode(day.weatherCode);
    final weekday =
        toBeginningOfSentenceCase(DateFormat.EEEE(locale).format(day.date));
    final dateLabel = DateFormat.MMMMd(locale).format(day.date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekday,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel · ${weatherDescription(l, day.weatherCode)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded,
                        size: 15, color: context.txtSecondary),
                    Text(
                      '${day.temperatureMax.round()}°',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: context.txtPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.arrow_downward_rounded,
                        size: 15, color: context.txtSecondary),
                    Text(
                      '${day.temperatureMin.round()}°',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: context.txtSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(condition.icon, color: condition.color, size: 48),
        ],
      ),
    );
  }
}

class _HourlyRow extends StatelessWidget {
  const _HourlyRow({required this.hour});

  final HourlyWeather hour;

  @override
  Widget build(BuildContext context) {
    final condition = WeatherCondition.fromCode(hour.weatherCode);
    final precip = hour.precipitationProbability;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              DateFormat('HH:mm').format(hour.time),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Icon(condition.icon, color: condition.color, size: 24),
          SizedBox(
            width: 44,
            child: (precip != null && precip > 0)
                ? Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '$precip%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  )
                : null,
          ),
          const Spacer(),
          _Stat(
            icon: Icons.air_rounded,
            value: '${hour.windSpeed.round()} kt',
            color: windColor(hour.windSpeed),
          ),
          if (hour.waveHeight != null) ...[
            const SizedBox(width: 12),
            _Stat(
              icon: Icons.waves_rounded,
              value: '${hour.waveHeight!.toStringAsFixed(1)} m',
              color: waveColor(hour.waveHeight!),
            ),
          ],
          const SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Text(
              '${hour.temperature.round()}°',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.color});

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
