enum PortType {
  marina,
  anchorage,
  fuel,
  commercial,
  fishing,
  other;
  // No `label` here on purpose: it returned English display text from the
  // domain layer, which the presentation layer already localizes
  // (`port_info_sheet`), and nothing called it.
}

class Port {
  const Port({
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

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String country;
  final PortType portType;
  final double? depthM;
  final List<String> facilities;
  final String? vhfChannel;
  final String? website;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Port && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
