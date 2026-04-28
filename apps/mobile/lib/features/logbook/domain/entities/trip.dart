class Trip {
  const Trip({
    required this.id,
    required this.boatId,
    required this.departurePort,
    required this.departureTime,
    this.arrivalPort,
    this.arrivalTime,
    this.distanceNm,
    this.maxSpeedKnots,
    this.avgSpeedKnots,
    this.notes,
    this.trackPoints,
    this.status = TripStatus.completed,
    this.engineHours,
    this.fuelConsumedL,
    this.crewMembers,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String boatId;
  final String departurePort;
  final DateTime departureTime;
  final String? arrivalPort;
  final DateTime? arrivalTime;
  final double? distanceNm;
  final double? maxSpeedKnots;
  final double? avgSpeedKnots;
  final String? notes;
  final List<TrackPoint>? trackPoints;
  final TripStatus status;
  final double? engineHours;
  final double? fuelConsumedL;
  final List<String>? crewMembers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Duration? get duration {
    if (arrivalTime == null) return null;
    return arrivalTime!.difference(departureTime);
  }

  Trip copyWith({
    String? id,
    String? boatId,
    String? departurePort,
    DateTime? departureTime,
    String? arrivalPort,
    DateTime? arrivalTime,
    double? distanceNm,
    double? maxSpeedKnots,
    double? avgSpeedKnots,
    String? notes,
    List<TrackPoint>? trackPoints,
    TripStatus? status,
    double? engineHours,
    double? fuelConsumedL,
    List<String>? crewMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      boatId: boatId ?? this.boatId,
      departurePort: departurePort ?? this.departurePort,
      departureTime: departureTime ?? this.departureTime,
      arrivalPort: arrivalPort ?? this.arrivalPort,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      distanceNm: distanceNm ?? this.distanceNm,
      maxSpeedKnots: maxSpeedKnots ?? this.maxSpeedKnots,
      avgSpeedKnots: avgSpeedKnots ?? this.avgSpeedKnots,
      notes: notes ?? this.notes,
      trackPoints: trackPoints ?? this.trackPoints,
      status: status ?? this.status,
      engineHours: engineHours ?? this.engineHours,
      fuelConsumedL: fuelConsumedL ?? this.fuelConsumedL,
      crewMembers: crewMembers ?? this.crewMembers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trip && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum TripStatus { recording, paused, completed }

class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speedKnots,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speedKnots;
}
