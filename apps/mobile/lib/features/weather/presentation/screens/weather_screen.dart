import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/core/error/exceptions.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/current_conditions.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/daily_forecast_list.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

/// Re-acquires the fix as well as the forecast. A stale or wrong location is
/// the most common reason the weather looks wrong, or does not load at all, so
/// every manual refresh path goes through here.
void _refresh(WidgetRef ref) {
  // The fix is what positionProvider derives from; invalidating only the
  // derived provider would hand back the same cached (missing) fix.
  ref.invalidate(locationFixProvider);
  ref.invalidate(weatherOverviewProvider);
}

/// True when the failure is "no network" rather than "the forecast broke".
bool _isOffline(Object error) =>
    error is NetworkException ||
    (error is DioException &&
        (error.error is NetworkException ||
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout));

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final overview = ref.watch(weatherOverviewProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(title: l.weather, transparent: true),
      body: GradientBackground(
        child: overview.when(
          loading: () => const NavisLoading(),
          // A localized reason, not the exception: users cannot act on a
          // DioException string, and it is not ours to put on screen. Offline
          // is worth telling apart — it is the one the user can fix.
          error: (error, stack) => NavisErrorWidget(
            message: _isOffline(error)
                ? l.noInternetConnection
                : l.weatherLoadFailed,
            onRetry: () => _refresh(ref),
          ),
          // Pull-to-refresh on both loaded and no-location: the no-location
          // state is exactly where the user needs a way to try again after
          // granting the permission in Settings. Both children scroll.
          data: (data) => RefreshIndicator(
            color: context.accent,
            backgroundColor: context.dialogSurface,
            onRefresh: () async => _refresh(ref),
            child: data == null
                ? _NoLocation(
                    reason: ref.watch(locationFixProvider).valueOrNull?.reason,
                    onRetry: () => _refresh(ref),
                  )
                : _OverviewBody(overview: data),
          ),
        ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.overview});

  final WeatherOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : context.ink;
    final secondary = isDark ? context.txtSecondary : context.inkMuted;

    final current = overview.current;
    final today = overview.daily.isNotEmpty ? overview.daily.first : null;
    final condition = WeatherCondition.fromCode(current.weatherCode);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        kToolbarHeight + MediaQuery.of(context).padding.top + 8,
        16,
        Dimens.navClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero: icon, temperature, description, today's high/low.
          Center(
            child: Column(
              children: [
                Icon(condition.icon, color: condition.color(context), size: 52)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 4),
                Text(
                  '${current.temperature.round()}°',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: context.accent,
                        fontWeight: FontWeight.w200,
                        fontSize: 92,
                        height: 1.0,
                      ),
                ).animate().fadeIn(duration: 600.ms).slideY(
                      begin: -0.1,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 2),
                Text(
                  weatherDescription(l, current.weatherCode),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: secondary,
                        letterSpacing: 0.5,
                      ),
                ).animate().fadeIn(delay: 150.ms, duration: 500.ms),
                if (today != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward_rounded,
                          size: 15, color: secondary),
                      Text(
                        '${today.temperatureMax.round()}°',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.arrow_downward_rounded,
                          size: 15, color: secondary),
                      Text(
                        '${today.temperatureMin.round()}°',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: secondary,
                            ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // The week as a list of days; tapping one opens its hourly detail
          // in place.
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l.sevenDayForecast,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (overview.daily.isNotEmpty)
            DailyForecastList(
              days: overview.daily,
              todayHours: overview.hourly,
            ).animate().fadeIn(
                  delay: 300.ms,
                  duration: 500.ms,
                )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.forecastNotAvailable,
                style: TextStyle(color: secondary),
              ),
            ),
          const SizedBox(height: 20),

          // Current conditions, as a grid of metric tiles.
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l.currentConditions,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          CurrentConditions(current: current).animate().fadeIn(
                delay: 400.ms,
                duration: 500.ms,
              ),
          const SizedBox(height: 12),

          // Navigation window suitability (from wind + waves).
          _NavWindowBadge(overview: overview).animate().fadeIn(
                delay: 450.ms,
                duration: 400.ms,
              ),

          // Tides (high/low), when available.
          if (overview.tideExtremes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TidesCard(extremes: overview.tideExtremes).animate().fadeIn(
                  delay: 480.ms,
                  duration: 400.ms,
                ),
          ],
        ],
      ),
    );
  }
}

/// Shown when there is no position: says which of the three things went wrong
/// and offers the action that fixes that one.
class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.reason, required this.onRetry});

  final NoFixReason? reason;
  final VoidCallback onRetry;

  /// Settings is the way out of "off" or "denied". "No fix yet" is not
  /// something Settings helps with — that one just needs another try.
  bool get _settingsHelps => reason != NoFixReason.unavailable;

  String _message(AppLocalizations l) => switch (reason) {
        NoFixReason.serviceDisabled => l.locationServicesOff,
        NoFixReason.unavailable => l.locationNoFixYet,
        // Denied, or not known yet (the fix provider was overridden or has not
        // reported): asking for access is the safe thing to say.
        _ => l.locationAccessNeeded,
      };

  @override
  Widget build(BuildContext context) {
    // Scrollable even though it fits, so the pull-to-refresh above it has a
    // gesture to work with.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.glassBg,
                shape: BoxShape.circle,
                border: Border.all(color: context.glassBorderColor),
              ),
              child: Icon(
                _settingsHelps
                    ? Icons.location_off
                    : Icons.location_searching_rounded,
                size: 40,
                color: context.txtSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _message(l),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.txtSecondary),
            ),
            const SizedBox(height: 24),
            if (_settingsHelps)
              NavisButton(
                label: l.openSettings,
                icon: Icons.settings_outlined,
                variant: NavisButtonVariant.secondary,
                compact: true,
                onPressed: Geolocator.openLocationSettings,
              ),
            const SizedBox(height: 10),
            NavisButton(
              label: l.retry,
              icon: Icons.refresh_rounded,
              variant: NavisButtonVariant.secondary,
              compact: true,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// A "good to sail" indicator based on current wind and wave conditions.
class _NavWindowBadge extends StatelessWidget {
  const _NavWindowBadge({required this.overview});

  final WeatherOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final wind = overview.current.windSpeed;
    final wave = overview.current.waveHeight;

    final (color, label, icon) = switch (null) {
      _ when wind <= 12 && wave <= 0.5 => (
          context.positive,
          l.sailConditionsGood,
          Icons.check_circle,
        ),
      _ when wind <= 20 && wave <= 1.2 => (
          context.caution,
          l.sailConditionsModerate,
          Icons.info,
        ),
      _ => (
          context.critical,
          l.sailConditionsAdverse,
          Icons.warning_amber_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l.windWavesSummary(
                    wind.round().toString(),
                    wave.toStringAsFixed(1),
                  ),
                  style: TextStyle(color: context.txtSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upcoming high/low tides.
class _TidesCard extends StatelessWidget {
  const _TidesCard({required this.extremes});

  final List<TideExtreme> extremes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    // Carrera = how much the water rises and falls = highest − lowest.
    final heights = extremes.map((e) => e.height).toList();
    final range = heights.isEmpty
        ? 0.0
        : heights.reduce((a, b) => a > b ? a : b) -
            heights.reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.glassBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waves, color: context.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                l.tides,
                style: TextStyle(
                  color: context.txtPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                l.tideRange(range.toStringAsFixed(1)),
                style: TextStyle(
                  color: context.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in extremes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    e.isHigh ? Icons.arrow_upward : Icons.arrow_downward,
                    color: e.isHigh ? context.accent : context.caution,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.isHigh ? l.tideHigh : l.tideLow,
                    style: TextStyle(color: context.txtPrimary),
                  ),
                  const Spacer(),
                  Text(
                    hhmm(e.time),
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${e.height >= 0 ? '+' : ''}${e.height.toStringAsFixed(1)} m',
                    style: TextStyle(color: context.txtSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
