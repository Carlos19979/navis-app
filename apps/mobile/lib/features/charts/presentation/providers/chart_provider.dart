import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Chart map state: the layer toggles plus the last *settled* camera.
///
/// Deliberately NOT updated while a gesture is in flight. The camera reports a
/// new position on every frame of a pan or pinch, and pushing that into
/// provider state rebuilt the whole screen — map layers, overlays and all — 60
/// times a second, which is what made panning and zooming feel stuck. The live
/// camera stays local to the screen (a ValueNotifier for the zoom readout, and
/// the ports controller for the viewport feed); only the resting position is
/// stored here, so returning to the tab reopens where the user left off.
class MapState {
  const MapState({
    required this.center,
    required this.zoom,
    this.showSeamarks = true,
    this.showPosition = true,
    this.showTracks = false,
    this.showPorts = true,
  });

  final LatLng center;
  final double zoom;
  final bool showSeamarks;
  final bool showPosition;
  final bool showTracks;
  final bool showPorts;

  MapState copyWith({
    LatLng? center,
    double? zoom,
    bool? showSeamarks,
    bool? showPosition,
    bool? showTracks,
    bool? showPorts,
  }) {
    return MapState(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      showSeamarks: showSeamarks ?? this.showSeamarks,
      showPosition: showPosition ?? this.showPosition,
      showTracks: showTracks ?? this.showTracks,
      showPorts: showPorts ?? this.showPorts,
    );
  }
}

final chartProvider = StateNotifierProvider<ChartNotifier, MapState>((ref) {
  return ChartNotifier();
});

class ChartNotifier extends StateNotifier<MapState> {
  ChartNotifier()
      : super(const MapState(
          center: LatLng(39.4699, -0.3763),
          zoom: 10,
        ));

  /// Records where the camera came to rest. Called on gesture *end*, never
  /// per frame, and it no-ops when nothing moved enough to matter.
  void settleCamera(LatLng center, double zoom) {
    if (zoom == state.zoom &&
        (center.latitude - state.center.latitude).abs() < 1e-6 &&
        (center.longitude - state.center.longitude).abs() < 1e-6) {
      return;
    }
    state = state.copyWith(center: center, zoom: zoom);
  }

  void toggleSeamarks() {
    state = state.copyWith(showSeamarks: !state.showSeamarks);
  }

  void togglePosition() {
    state = state.copyWith(showPosition: !state.showPosition);
  }

  void toggleTracks() {
    state = state.copyWith(showTracks: !state.showTracks);
  }

  void togglePorts() {
    state = state.copyWith(showPorts: !state.showPorts);
  }

  void centerOnPosition(LatLng position) {
    state = state.copyWith(center: position, zoom: 14);
  }
}
