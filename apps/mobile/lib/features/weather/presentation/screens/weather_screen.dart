import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/core/error/exceptions.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/theme/tone.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/boat_actions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/active_boat_provider.dart';
import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/current_conditions.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/daily_forecast_list.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/models/sail_window.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_action_button.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_section.dart';

/// Key on the scrollable, so a test can scroll the forecast without guessing
/// which of the nested scrollables is the page.
const weatherScrollKey = Key('weather-scroll');

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
            backgroundColor: context.surfaceRaised,
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
    final current = overview.current;
    final today = overview.daily.isNotEmpty ? overview.daily.first : null;

    return SingleChildScrollView(
      key: weatherScrollKey,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Dimens.spaceLg,
        kToolbarHeight + MediaQuery.of(context).padding.top,
        Dimens.spaceLg,
        Dimens.navClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(current: current, today: today).entrance(),

          // The verdict, and the way to act on it. It sits directly under the
          // temperature and above every detail on purpose: the question this
          // tab gets opened with is "can I go out today", and the forecast
          // used to answer it two screenfuls down, in a badge with nothing to
          // press.
          const SizedBox(height: Dimens.spaceXl),
          _SailWindowBlock(overview: overview).entrance(index: 1),

          const SizedBox(height: Dimens.spaceXl),
          NavisSection(
            title: l.sevenDayForecast,
            padding: EdgeInsets.zero,
            child: overview.daily.isEmpty
                ? Text(
                    l.forecastNotAvailable,
                    style: NavisType.bodySm.copyWith(color: context.inkMuted),
                  )
                : DailyForecastList(
                    days: overview.daily,
                    todayHours: overview.hourly,
                  ),
          ).entrance(index: 2),

          const SizedBox(height: Dimens.spaceXl),
          NavisSection(
            title: l.currentConditions,
            padding: EdgeInsets.zero,
            child: CurrentConditions(current: current),
          ).entrance(index: 3),

          if (overview.tideExtremes.isNotEmpty) ...[
            const SizedBox(height: Dimens.spaceXl),
            _Tides(extremes: overview.tideExtremes).entrance(index: 4),
          ],
        ],
      ),
    );
  }
}

/// Temperature, sky, and today's range.
class _Hero extends StatelessWidget {
  const _Hero({required this.current, required this.today});

  final Weather current;
  final DailyWeather? today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final condition = WeatherCondition.fromCode(current.weatherCode);

    return Center(
      child: Column(
        children: [
          Icon(
            condition.icon,
            color: condition.color(context),
            size: Dimens.iconXl,
          ),
          const SizedBox(height: Dimens.spaceXs),
          // Tabular figures: without them the reading twitches sideways every
          // time the tens digit changes on a refresh.
          Text(
            '${current.temperature.round()}°',
            style: NavisType.numeral.copyWith(color: context.ink),
          ),
          Text(
            weatherDescription(l, current.weatherCode),
            style: NavisType.body.copyWith(color: context.inkMuted),
          ),
          if (today != null) ...[
            const SizedBox(height: Dimens.spaceXs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: Dimens.iconSm,
                  color: context.inkMuted,
                ),
                Text(
                  '${today!.temperatureMax.round()}°',
                  style: NavisType.label.copyWith(color: context.ink),
                ),
                const SizedBox(width: Dimens.spaceMd),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: Dimens.iconSm,
                  color: context.inkMuted,
                ),
                Text(
                  '${today!.temperatureMin.round()}°',
                  style: NavisType.label.copyWith(color: context.inkMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The forecast's answer to "can I go out", with the way to go out.
///
/// Two things changed here. The verdict now comes from
/// [SailWindow.evaluate] — this screen had its own copy of the thresholds, so
/// Today and the forecast could disagree about the same wind. And it carries
/// the sail action: telling a sailor the conditions are perfect and leaving
/// them to find the button on another tab is the whole reason this tab counted
/// as inert.
class _SailWindowBlock extends ConsumerWidget {
  const _SailWindowBlock({required this.overview});

  final WeatherOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final wind = overview.current.windSpeed;
    final wave = overview.current.waveHeight;
    final window = SailWindow.evaluate(windKnots: wind, waveMetres: wave);

    final (tone, label, icon, hint) = switch (window) {
      SailWindow.good => (
          NavisTone.positive,
          l.sailConditionsGood,
          Icons.check_circle_rounded,
          l.sailWindowGoodHint,
        ),
      SailWindow.moderate => (
          NavisTone.caution,
          l.sailConditionsModerate,
          Icons.info_rounded,
          l.sailWindowModerateHint,
        ),
      SailWindow.adverse => (
          NavisTone.critical,
          l.sailConditionsAdverse,
          Icons.warning_amber_rounded,
          l.sailWindowAdverseHint,
        ),
    };
    final accent = context.toneAccent(tone);
    final boat = ref.watch(activeBoatProvider);

    return DecoratedBox(
      // A neutral surface with the tone in the glyph and the edge, not a tinted
      // fill. An amber wash over the dark canvas comes out brown — the exact
      // colour this redesign already had to remove once — and on white it is a
      // pale beige that reads as a disabled card. The tone belongs in the icon,
      // where amber is amber in both themes.
      decoration: BoxDecoration(
        color: context.surfaceSunken,
        borderRadius: BorderRadius.circular(Dimens.radiusSurface),
        border: Border.all(color: context.washBorder(accent)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: Dimens.iconLg),
                const SizedBox(width: Dimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: NavisType.title3.copyWith(color: context.ink),
                      ),
                      Text(
                        l.windWavesSummary(
                          wind.round().toString(),
                          Measure.decimal(locale, wave),
                        ),
                        style: NavisType.bodySm.copyWith(
                          color: context.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceSm),
            Text(
              hint,
              style: NavisType.bodySm.copyWith(color: context.inkMuted),
            ),
            // No boat, or a guest without permission to record: then there is
            // nothing honest to offer, and the block stays a verdict.
            if (boat != null && BoatActions.canSail(boat)) ...[
              const SizedBox(height: Dimens.spaceLg),
              _SailAction(boat: boat, window: window),
            ],
          ],
        ),
      ),
    );
  }
}

class _SailAction extends ConsumerWidget {
  const _SailAction({required this.boat, required this.window});

  final Boat boat;
  final SailWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return NavisActionBar(
      actions: [
        NavisActionButton(
          icon: Icons.sailing_rounded,
          label: BoatActions.sailLabel(l, ref),
          // Filled when the sea says go, outlined when it says think about it:
          // the button is as loud as the conditions deserve, and never absent,
          // because "adverse" is a judgement and the skipper's call.
          primary: window == SailWindow.good,
          onTap: () => BoatActions.sail(context, ref, boat),
        ),
      ],
    );
  }
}

/// Upcoming high and low water.
class _Tides extends StatelessWidget {
  const _Tides({required this.extremes});

  final List<TideExtreme> extremes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    // Range = how far the water rises and falls = highest − lowest.
    final heights = extremes.map((e) => e.height).toList();
    final range = heights.isEmpty
        ? 0.0
        : heights.reduce((a, b) => a > b ? a : b) -
            heights.reduce((a, b) => a < b ? a : b);

    return NavisList(
      title: l.tides,
      action: Text(
        l.tideRange(Measure.decimal(locale, range)),
        style: NavisType.overline.copyWith(color: context.inkMuted),
      ),
      children: [
        for (final e in extremes)
          NavisRow(
            icon: e.isHigh
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            iconColor: e.isHigh ? context.accent : context.caution,
            title: e.isHigh ? l.tideHigh : l.tideLow,
            subtitle: NavisDateUtils.formatTime(e.time),
            value: Measure.signedMetres(locale, e.height),
          ),
      ],
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
    final l = AppLocalizations.of(context)!;
    // Scrollable even though it fits, so the pull-to-refresh above it has a
    // gesture to work with.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: NavisEmptyState(
            icon: _settingsHelps
                ? Icons.location_off_rounded
                : Icons.location_searching_rounded,
            message: _message(l),
            actionLabel: _settingsHelps ? l.openSettings : l.retry,
            onAction:
                _settingsHelps ? Geolocator.openLocationSettings : onRetry,
            secondaryActionLabel: _settingsHelps ? l.retry : null,
            onSecondaryAction: _settingsHelps ? onRetry : null,
          ),
        ),
      ),
    );
  }
}
