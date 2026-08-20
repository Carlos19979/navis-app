import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/shared/utils/native_share.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/utils/status_colors.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tripAsync = ref.watch(tripProvider(tripId));

    // On a shared boat the logbook holds the whole crew's trips, and only the
    // author or the boat's owner may change one. The server answers that with
    // `can_manage`; offering buttons that end in a 403 (or, worse, the "trip
    // not found" this used to produce) is not a permission check.
    final canManage = tripAsync.valueOrNull?.canManage ?? true;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: l.tripDetails,
          showBack: true,
          actions: [
            if (canManage) ...[
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l.shareTrip,
                onPressed: () => _shareTrip(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l.editTrip,
                onPressed: () => context.push(Routes.tripEdit(tripId)),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outlined,
                  color: context.critical,
                ),
                tooltip: l.deleteTrip,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded),
                tooltip: l.tripReadOnly,
                onPressed: () => NavisSnackbar.info(context, l.tripReadOnly),
              ),
          ],
        ),
        body: tripAsync.when(
          loading: () => const NavisLoading(),
          error: (error, stack) => NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(tripProvider(tripId)),
          ),
          data: (trip) {
            final trackPoints = trip.trackPoints ?? [];
            final hasTrack = trackPoints.isNotEmpty;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTrack) ...[
                    _buildMapCard(context, trackPoints),
                    const SizedBox(height: 12),
                    const _SpeedLegend(),
                    const SizedBox(height: 16),
                  ],
                  _buildRouteCard(context, trip),
                  const SizedBox(height: 12),
                  _buildStatsCard(context, trip),
                  if (trip.engineHours != null ||
                      trip.fuelConsumedL != null) ...[
                    const SizedBox(height: 12),
                    _buildEngineCard(context, trip),
                  ],
                  if (trip.crewMembers != null &&
                      trip.crewMembers!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCrewCard(context, trip),
                  ],
                  if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildNotesCard(context, trip),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapCard(
    BuildContext context,
    List<TrackPoint> trackPoints,
  ) {
    return GestureDetector(
      onTap: () => _openFullScreenMap(context, trackPoints),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.glassBorderColor,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RepaintBoundary(
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        // Framed to the whole track, not centred on its first
                        // point at a fixed zoom 12 — a trip longer than a few
                        // miles ran straight off the card, so the preview
                        // showed the start and none of the voyage.
                        initialCameraFit: CameraFit.bounds(
                          bounds: _trackBounds(trackPoints),
                          padding: const EdgeInsets.all(Dimens.spaceXl),
                          // A short hop is a handful of points inside a few
                          // hundred metres; fitting that literally zooms past
                          // any tile that exists.
                          maxZoom: 15,
                        ),
                        minZoom: 3,
                        maxZoom: 18,
                        // Navy while tiles load, instead of flutter_map's
                        // default light grey flashing inside a dark card.
                        backgroundColor: AppColors.navy,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        OpenSeaMapTileProvider.baseLayer(),
                        PolylineLayer(
                          polylines: _buildSpeedPolylines(context, trackPoints),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                trackPoints.first.latitude,
                                trackPoints.first.longitude,
                              ),
                              width: 14,
                              height: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.positive,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.positive
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Marker(
                              point: LatLng(
                                trackPoints.last.latitude,
                                trackPoints.last.longitude,
                              ),
                              width: 14,
                              height: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.critical,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.critical
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.fullscreen, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenMap(
    BuildContext context,
    List<TrackPoint> trackPoints,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TripMapFullScreen(
          trackPoints: trackPoints,
          polylines: _buildSpeedPolylines(context, trackPoints),
        ),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.flight_takeoff,
            label: AppLocalizations.of(context)!.departure,
            value:
                '${trip.departurePort}\n${NavisDateUtils.formatDateTime(trip.departureTime)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 0.5,
              color: context.glassBorderColor,
            ),
          ),
          _DetailRow(
            icon: Icons.flight_land,
            label: AppLocalizations.of(context)!.arrival,
            value: trip.arrivalPort != null
                ? '${trip.arrivalPort}'
                    '${trip.arrivalTime != null ? '\n${NavisDateUtils.formatDateTime(trip.arrivalTime!)}' : ''}'
                : AppLocalizations.of(context)!.notRecorded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: Row(
        children: [
          if (trip.distanceNm != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.distance,
                value: DistanceUtils.formatDistance(
                  trip.distanceNm!,
                ),
                icon: Icons.straighten,
              ),
            ),
          if (trip.duration != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.duration,
                value: NavisDateUtils.formatDuration(
                  trip.duration!,
                ),
                icon: Icons.schedule,
              ),
            ),
          if (trip.avgSpeedKnots != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.avgSpeed,
                value: DistanceUtils.formatSpeed(
                  trip.avgSpeedKnots!,
                ),
                icon: Icons.speed,
              ),
            ),
          if (trip.maxSpeedKnots != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.maxSpeed,
                value: DistanceUtils.formatSpeed(
                  trip.maxSpeedKnots!,
                ),
                icon: Icons.speed,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEngineCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: Column(
        children: [
          if (trip.engineHours != null)
            _DetailRow(
              icon: Icons.engineering,
              label: AppLocalizations.of(context)!.engineHours,
              value: '${trip.engineHours!.toStringAsFixed(1)} h',
            ),
          if (trip.engineHours != null && trip.fuelConsumedL != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: context.glassBorderColor,
            ),
            const SizedBox(height: 12),
          ],
          if (trip.fuelConsumedL != null)
            _DetailRow(
              icon: Icons.local_gas_station,
              label: AppLocalizations.of(context)!.fuelConsumed,
              value: '${trip.fuelConsumedL!.toStringAsFixed(1)} L',
            ),
        ],
      ),
    );
  }

  Widget _buildCrewCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: _DetailRow(
        icon: Icons.group,
        label: AppLocalizations.of(context)!.crew,
        value: trip.crewMembers!.join(', '),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: _DetailRow(
        icon: Icons.notes,
        label: AppLocalizations.of(context)!.notes,
        value: trip.notes!,
      ),
    );
  }

  /// The rectangle that holds every point of the track.
  ///
  /// `LatLngBounds.fromPoints` throws on an empty list, and the caller already
  /// guards on `trackPoints.isNotEmpty`, but a single-point track would give a
  /// zero-area box — so it is nudged outwards to something a camera can fit.
  LatLngBounds _trackBounds(List<TrackPoint> trackPoints) {
    final points = [
      for (final p in trackPoints) LatLng(p.latitude, p.longitude),
    ];
    final bounds = LatLngBounds.fromPoints(points);
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
      const nudge = 0.002; // ~200 m
      return LatLngBounds(
        LatLng(bounds.south - nudge, bounds.west - nudge),
        LatLng(bounds.north + nudge, bounds.east + nudge),
      );
    }
    return bounds;
  }

  List<Polyline> _buildSpeedPolylines(
    BuildContext context,
    List<TrackPoint> trackPoints,
  ) {
    if (trackPoints.length < 2) return [];

    final polylines = <Polyline>[];
    for (int i = 0; i < trackPoints.length - 1; i++) {
      final speed = trackPoints[i].speedKnots ?? 0;
      final color = context.speedColor(speed);

      polylines.add(
        Polyline(
          points: [
            LatLng(
              trackPoints[i].latitude,
              trackPoints[i].longitude,
            ),
            LatLng(
              trackPoints[i + 1].latitude,
              trackPoints[i + 1].longitude,
            ),
          ],
          color: color,
          strokeWidth: 3.5,
        ),
      );
    }
    return polylines;
  }

  String _summaryText(Trip trip) {
    final distance = trip.distanceNm != null
        ? '${trip.distanceNm!.toStringAsFixed(1)} NM'
        : '';
    final duration = trip.duration != null
        ? '${trip.duration!.inHours}h ${trip.duration!.inMinutes % 60}m'
        : '';
    return (StringBuffer()
          ..writeln('${trip.departurePort} \u2192 ${trip.arrivalPort ?? '?'}')
          ..writeln(trip.departureTime.toLocal().toString().substring(0, 16))
          ..writeln(
            [distance, duration].where((s) => s.isNotEmpty).join(' \u2022 '),
          ))
        .toString();
  }

  /// Asks what to share, then shares it.
  ///
  /// The choice comes back as the sheet's pop value and the share happens
  /// *after* it closes: opening the OS share sheet while a route is still
  /// dismissing is how these things end up doing nothing at all.
  Future<void> _shareTrip(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final trip = ref.read(tripProvider(tripId)).valueOrNull;
    if (trip == null) return;

    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.dialogSurface,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.link, color: context.accent),
              title: Text(l.shareTripLink),
              subtitle: Text(l.shareTripLinkSubtitle),
              onTap: () => Navigator.of(sheetCtx).pop(_ShareChoice.link),
            ),
            ListTile(
              leading: Icon(Icons.short_text, color: context.accent),
              title: Text(l.shareTripSummary),
              subtitle: Text(l.shareTripSummarySubtitle),
              onTap: () => Navigator.of(sheetCtx).pop(_ShareChoice.summary),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _ShareChoice.link:
        await _shareLink(context, ref, trip);
      case _ShareChoice.summary:
        await shareNavisText(
          context,
          text: '${_summaryText(trip)}\n${l.madeWithNavis}',
          subject: l.shareTrip,
        );
    }
  }

  Future<void> _shareLink(
      BuildContext context, WidgetRef ref, Trip trip) async {
    final l = AppLocalizations.of(context)!;
    final String url;
    try {
      url = await ref.read(tripRepositoryProvider).shareTrip(trip.id);
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.shareLinkFailed);
      return;
    }
    if (!context.mounted) return;
    await shareNavisText(
      context,
      text: '${_summaryText(trip)}\n$url',
      subject: l.shareTrip,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.deleteTrip,
      message: l.deleteTripConfirm,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!confirmed) return;
    final trip = ref.read(tripProvider(tripId)).valueOrNull;
    try {
      final repo = ref.read(tripRepositoryProvider);
      await repo.deleteTrip(tripId);
      if (trip != null) {
        ref.invalidate(boatTripsProvider(trip.boatId));
      }
      ref.invalidate(tripProvider(tripId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tripDeleted)),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      // 403 is not a failure to explain with an exception string: it is the
      // owner not having granted this. 404 after a successful read means the
      // trip is already gone, which is what the user wanted anyway.
      final status = e.response?.statusCode;
      NavisSnackbar.error(
        context,
        switch (status) {
          403 => l.tripDeleteForbidden,
          404 => l.tripAlreadyDeleted,
          _ => l.failedToDelete,
        },
      );
      if (status == 404) {
        ref.invalidate(tripProvider(tripId));
        context.pop();
      }
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.failedToDelete);
    }
  }
}

/// What the share sheet came back with.
enum _ShareChoice { link, summary }

class _SpeedLegend extends StatelessWidget {
  const _SpeedLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: context.accent, label: '<3 kt'),
        const SizedBox(width: 12),
        _LegendDot(color: context.positive, label: '3-6 kt'),
        const SizedBox(width: 12),
        _LegendDot(color: context.caution, label: '6-12 kt'),
        const SizedBox(width: 12),
        _LegendDot(color: context.critical, label: '>12 kt'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.txtSecondary,
              ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.glassBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.glassBorderColor,
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 16, color: context.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.txtSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: context.accent),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.accent,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.txtSecondary,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

/// Full-screen, interactive view of a finished trip's track.
class _TripMapFullScreen extends StatelessWidget {
  const _TripMapFullScreen({
    required this.trackPoints,
    required this.polylines,
  });

  /// Matches the tile layers' `maxZoom` (see [OpenSeaMapTileProvider]) and the
  /// chart screen. Above it there are no tiles to draw.
  static const _maxZoom = 18.0;
  static const _minZoom = 3.0;

  final List<TrackPoint> trackPoints;
  final List<Polyline> polylines;

  @override
  Widget build(BuildContext context) {
    final points = trackPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              // Both bounds are needed here, and this is why the map came up
              // blank: `CameraFit.bounds` divides the viewport by the track's
              // extent, so a short hop (or a track whose points are all within
              // a few metres) asks for a zoom far past 18 — and above the tile
              // layer's maxZoom nothing is painted at all, leaving flutter_map's
              // grey backgroundColor. Capping the fit keeps tiles on screen.
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              backgroundColor: AppColors.navy,
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.all(48),
                maxZoom: _maxZoom,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              OpenSeaMapTileProvider.baseLayer(),
              OpenSeaMapTileProvider.seamarkLayer(),
              PolylineLayer(polylines: polylines),
              MarkerLayer(
                markers: [
                  _endpointMarker(points.first, context.positive),
                  _endpointMarker(points.last, context.critical),
                ],
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: AppLocalizations.of(context)!.goBack,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _endpointMarker(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 16,
      height: 16,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}
