import 'package:navis_mobile/features/ports/domain/entities/port.dart';

final class PortModel {
  const PortModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.country,
    required this.portType,
    this.depthM,
    this.facilities = const [],
    this.vhfChannel,
    this.website,
  });

  factory PortModel.fromJson(Map<String, dynamic> json) {
    return PortModel(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      country: json['country'] as String,
      portType: json['port_type'] as String,
      depthM: (json['depth_m'] as num?)?.toDouble(),
      facilities: (json['facilities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      vhfChannel: json['vhf_channel'] as String?,
      website: json['website'] as String?,
    );
  }

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String country;
  final String portType;
  final double? depthM;
  final List<String> facilities;
  final String? vhfChannel;
  final String? website;

  Port toEntity() {
    return Port(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      country: country,
      portType: PortType.values.firstWhere(
        (t) => t.name == portType,
        orElse: () => PortType.other,
      ),
      depthM: depthM,
      facilities: facilities,
      vhfChannel: vhfChannel,
      website: website,
    );
  }
}
