class Boat {
  const Boat({
    required this.id,
    required this.name,
    required this.registration,
    required this.type,
    required this.lengthMeters,
    this.homePort,
    this.photoUrl,
    this.ownerId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String registration;
  final String type;
  final double lengthMeters;
  final String? homePort;
  final String? photoUrl;
  final String? ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Boat copyWith({
    String? id,
    String? name,
    String? registration,
    String? type,
    double? lengthMeters,
    String? homePort,
    String? photoUrl,
    String? ownerId,
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
      photoUrl: photoUrl ?? this.photoUrl,
      ownerId: ownerId ?? this.ownerId,
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
          photoUrl == other.photoUrl;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        registration,
        type,
        lengthMeters,
        homePort,
        photoUrl,
      );

  @override
  String toString() => 'Boat(id: $id, name: $name, registration: $registration)';
}
