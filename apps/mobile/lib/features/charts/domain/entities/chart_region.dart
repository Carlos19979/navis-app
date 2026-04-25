import 'package:latlong2/latlong.dart';

class ChartRegion {
  const ChartRegion({
    required this.id,
    required this.name,
    required this.northEast,
    required this.southWest,
    this.isDownloaded = false,
  });

  final String id;
  final String name;
  final LatLng northEast;
  final LatLng southWest;
  final bool isDownloaded;

  ChartRegion copyWith({
    String? id,
    String? name,
    LatLng? northEast,
    LatLng? southWest,
    bool? isDownloaded,
  }) {
    return ChartRegion(
      id: id ?? this.id,
      name: name ?? this.name,
      northEast: northEast ?? this.northEast,
      southWest: southWest ?? this.southWest,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}
