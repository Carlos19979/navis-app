import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Snapped visible bounding box driving the viewport ports fetch. Kept as a
/// plain record (not a ports-feature type) so this charts provider stays free
/// of cross-feature imports; it is structurally compatible with the ports
/// feature's `PortsBBox`.
typedef ChartBBox = ({
  double minLon,
  double minLat,
  double maxLon,
  double maxLat,
});

class MapState {
  const MapState({
    required this.center,
    required this.zoom,
    this.showSeamarks = true,
    this.showPosition = true,
    this.showTracks = false,
    this.showPorts = true,
    this.portsBBox,
  });

  final LatLng center;
  final double zoom;
  final bool showSeamarks;
  final bool showPosition;
  final bool showTracks;
  final bool showPorts;

  /// Snapped bounds of the currently visible area; null until the map reports
  /// its first camera position.
  final ChartBBox? portsBBox;

  MapState copyWith({
    LatLng? center,
    double? zoom,
    bool? showSeamarks,
    bool? showPosition,
    bool? showTracks,
    bool? showPorts,
    ChartBBox? portsBBox,
  }) {
    return MapState(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      showSeamarks: showSeamarks ?? this.showSeamarks,
      showPosition: showPosition ?? this.showPosition,
      showTracks: showTracks ?? this.showTracks,
      showPorts: showPorts ?? this.showPorts,
      portsBBox: portsBBox ?? this.portsBBox,
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

  void setCenter(LatLng center) {
    state = state.copyWith(center: center);
  }

  void setZoom(double zoom) {
    state = state.copyWith(zoom: zoom);
  }

  /// Updates the snapped visible bounds, but only when they actually change,
  /// so panning within a snap-grid cell does not trigger a rebuild/refetch.
  void setPortsBBox(ChartBBox bbox) {
    if (state.portsBBox == bbox) return;
    state = state.copyWith(portsBBox: bbox);
  }

  void zoomIn() {
    if (state.zoom < 18) {
      state = state.copyWith(zoom: state.zoom + 1);
    }
  }

  void zoomOut() {
    if (state.zoom > 3) {
      state = state.copyWith(zoom: state.zoom - 1);
    }
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
