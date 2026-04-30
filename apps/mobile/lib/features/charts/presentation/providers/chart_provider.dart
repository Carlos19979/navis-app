import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class MapState {
  const MapState({
    required this.center,
    required this.zoom,
    this.showSeamarks = true,
    this.showPosition = true,
    this.showTracks = false,
  });

  final LatLng center;
  final double zoom;
  final bool showSeamarks;
  final bool showPosition;
  final bool showTracks;

  MapState copyWith({
    LatLng? center,
    double? zoom,
    bool? showSeamarks,
    bool? showPosition,
    bool? showTracks,
  }) {
    return MapState(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      showSeamarks: showSeamarks ?? this.showSeamarks,
      showPosition: showPosition ?? this.showPosition,
      showTracks: showTracks ?? this.showTracks,
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

  void centerOnPosition(LatLng position) {
    state = state.copyWith(center: position, zoom: 14);
  }
}
