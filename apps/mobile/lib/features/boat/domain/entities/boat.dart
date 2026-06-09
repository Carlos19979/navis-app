class Boat {
  const Boat({
    required this.id,
    required this.name,
    required this.registration,
    required this.type,
    required this.lengthMeters,
    this.homePort,
    this.homePortLat,
    this.homePortLon,
    this.photoUrl,
    this.ownerId,
    this.isOwner = true,
    this.canRecord = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String registration;
  final String type;
  final double lengthMeters;
  final String? homePort;
  final double? homePortLat;
  final double? homePortLon;
  final String? photoUrl;
  final String? ownerId;
  final bool isOwner;
  final bool canRecord;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Boat copyWith({
    String? id,
    String? name,
    String? registration,
    String? type,
    double? lengthMeters,
    String? homePort,
    double? homePortLat,
    double? homePortLon,
    String? photoUrl,
    String? ownerId,
    bool? isOwner,
    bool? canRecord,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Boat(
      id: id ?? this.id,
      name: name ?? this.name,
      registration: registration ?? this.registration,
      type: type ?? this.type,
      lengthMeters: lengthMeters ?? this.lengthMeters,
      homePort: homePort ?? this.homePort,
      homePortLat: homePortLat ?? this.homePortLat,
      homePortLon: homePortLon ?? this.homePortLon,
      photoUrl: photoUrl ?? this.photoUrl,
      ownerId: ownerId ?? this.ownerId,
      isOwner: isOwner ?? this.isOwner,
      canRecord: canRecord ?? this.canRecord,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Boat &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          registration == other.registration &&
          type == other.type &&
          lengthMeters == other.lengthMeters &&
          homePort == other.homePort &&
          homePortLat == other.homePortLat &&
          homePortLon == other.homePortLon &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        registration,
        type,
        lengthMeters,
        homePort,
        homePortLat,
        homePortLon,
        photoUrl,
      );

  @override
  String toString() =>
      'Boat(id: $id, name: $name, registration: $registration)';
}
