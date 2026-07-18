import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/anchor/presentation/providers/anchor_watch_provider.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/position_indicator.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class AnchorAlarmScreen extends ConsumerStatefulWidget {
  const AnchorAlarmScreen({super.key, this.boatId});

  final String? boatId;

  @override
  ConsumerState<AnchorAlarmScreen> createState() => _AnchorAlarmScreenState();
}

class _AnchorAlarmScreenState extends ConsumerState<AnchorAlarmScreen>
    with WidgetsBindingObserver {
  final _mapController = MapController();
  LatLng _center = const LatLng(39.5696, 2.6347); // Palma, until the first fix.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the screen awake while the anchor screen is open (foreground watch).
    // Best-effort — a missing wakelock plugin must not break the screen.
    unawaited(WakelockPlus.enable().catchError((_) {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedPosition());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable().catchError((_) {}));
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(anchorWatchProvider.notifier).ensureStream();
    }
  }

  Future<void> _seedPosition() async {
    final armed = ref.read(anchorWatchProvider).anchorPosition;
    if (armed != null) {
      _center = armed;
      _mapController.move(armed, 16);
      return;
    }
    try {
      final fix = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _center = LatLng(fix.latitude, fix.longitude));
      _mapController.move(_center, 16);
    } catch (_) {
      // No fix yet — the map stays on the default center.
    }
  }

  Future<void> _dropAnchor() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final result = await ref
        .read(anchorWatchProvider.notifier)
        .dropAnchor(boatId: widget.boatId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case AnchorArmResult.armed:
        final anchor = ref.read(anchorWatchProvider).anchorPosition;
        if (anchor != null) _mapController.move(anchor, 16);
      case AnchorArmResult.permissionDenied:
        NavisSnackbar.error(context, l.anchorPermissionDenied);
      case AnchorArmResult.noFix:
        NavisSnackbar.error(context, l.anchorNoFix);
    }
  }

  Future<void> _disarm() async {
    await ref.read(anchorWatchProvider.notifier).disarm();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final canUse = ref.watch(effectiveTierProvider).canAnchorAlarm;
    final watch = ref.watch(anchorWatchProvider);

    if (!canUse) {
      return NavisScaffold(
        title: l.anchorAlarmTitle,
        showBack: true,
        body: NavisEmptyState(
          icon: Icons.anchor_rounded,
          message: l.anchorAlarmTitle,
          description: l.paywallReasonAnchor,
          actionLabel: l.subscribe,
          onAction: () => showPaywall(context, ref,
              reason: l.paywallReasonAnchor, requiredTier: PlanTier.plus),
        ),
      );
    }

    final anchor = watch.anchorPosition;
    final current = watch.currentPosition;

    return NavisScaffold(
      title: l.anchorAlarmTitle,
      showBack: true,
      body: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: anchor ?? _center,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                OpenSeaMapTileProvider.baseLayer,
                OpenSeaMapTileProvider.seamarkLayer,
                if (anchor != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: anchor,
                        radius: watch.radiusMeters,
                        useRadiusInMeter: true,
                        color:
                            (watch.isDragging ? AppColors.red : AppColors.cyan)
                                .withValues(alpha: 0.12),
                        borderColor:
                            watch.isDragging ? AppColors.red : AppColors.cyan,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (anchor != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: anchor,
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.anchor,
                          color:
                              watch.isDragging ? AppColors.red : AppColors.cyan,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                if (current != null) PositionIndicator(position: current),
              ],
            ),
          ),
          if (watch.isDragging) _DragBanner(watch: watch),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ControlPanel(
              watch: watch,
              busy: _busy,
              onDrop: _dropAnchor,
              onDisarm: _disarm,
              onRadius: (v) =>
                  ref.read(anchorWatchProvider.notifier).adjustRadius(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragBanner extends ConsumerWidget {
  const _DragBanner({required this.watch});

  final AnchorWatchState watch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(anchorWatchProvider.notifier);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.anchorDragTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.anchorDragBody,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: NavisButton(
                      label: watch.alarmSilenced
                          ? l.anchorSilenced
                          : l.anchorSilence,
                      icon: Icons.volume_off_rounded,
                      variant: NavisButtonVariant.secondary,
                      compact: true,
                      isDisabled: watch.alarmSilenced,
                      onPressed: notifier.silenceAlarm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NavisButton(
                      label: l.anchorRecenter,
                      icon: Icons.my_location_rounded,
                      variant: NavisButtonVariant.secondary,
                      compact: true,
                      onPressed: notifier.recenter,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.watch,
    required this.busy,
    required this.onDrop,
    required this.onDisarm,
    required this.onRadius,
  });

  final AnchorWatchState watch;
  final bool busy;
  final VoidCallback onDrop;
  final VoidCallback onDisarm;
  final ValueChanged<double> onRadius;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final armed = watch.isArmed;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dialogSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.glassBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (armed) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                  label: l.anchorDistance,
                  value: '${watch.distanceMeters.round()} m',
                  color: watch.isDragging ? AppColors.red : context.txtPrimary,
                ),
                _Metric(
                  label: l.anchorRadius,
                  value: '${watch.radiusMeters.round()} m',
                  color: context.txtPrimary,
                ),
                _Metric(
                  label: l.anchorMaxDistance,
                  value: '${watch.maxDistanceMeters.round()} m',
                  color: context.txtSecondary,
                ),
                _Metric(
                  label: l.anchorGpsAccuracy,
                  value: watch.gpsAccuracy == null
                      ? '—'
                      : '±${watch.gpsAccuracy!.round()} m',
                  color: context.txtSecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.adjust_rounded,
                    size: 18, color: context.txtSecondary),
                Expanded(
                  child: Slider(
                    value: watch.radiusMeters
                        .clamp(kMinAnchorRadiusM, kMaxAnchorRadiusM),
                    min: kMinAnchorRadiusM,
                    max: kMaxAnchorRadiusM,
                    divisions: 27,
                    label: '${watch.radiusMeters.round()} m',
                    activeColor: AppColors.cyan,
                    onChanged: onRadius,
                  ),
                ),
              ],
            ),
            NavisButton(
              label: l.anchorDisarm,
              icon: Icons.stop_rounded,
              variant: NavisButtonVariant.danger,
              onPressed: onDisarm,
            ),
          ] else ...[
            Text(
              l.anchorKeepPluggedIn,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            NavisButton(
              label: l.anchorDropHere,
              icon: Icons.anchor_rounded,
              isLoading: busy,
              onPressed: onDrop,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l.anchorDisclaimer,
            style: TextStyle(
              color: context.txtSecondary.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.txtSecondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
