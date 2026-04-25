import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';

class TripModel {
  const TripModel({
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
    this.status = 'completed',
    this.createdAt,
    this.updatedAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      departurePort: json['departure_port'] as String,
      departureTime: DateTime.parse(json['departure_time'] as String),
      arrivalPort: json['arrival_port'] as String?,
      arrivalTime: json['arrival_time'] != null
          ? DateTime.parse(json['arrival_time'] as String)
          : null,
      distanceNm: (json['distance_nm'] as num?)?.toDouble(),
      maxSpeedKnots: (json['max_speed_knots'] as num?)?.toDouble(),
      avgSpeedKnots: (json['avg_speed_knots'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      trackPoints: json['track_points'] != null
          ? (json['track_points'] as List<dynamic>)
              .map((tp) => TrackPointModel.fromJson(tp as Map<String, dynamic>))
              .toList()
          : null,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  factory TripModel.fromEntity(Trip trip) {
    return TripModel(
      id: trip.id,
      boatId: trip.boatId,
      departurePort: trip.departurePort,
      departureTime: trip.departureTime,
      arrivalPort: trip.arrivalPort,
      arrivalTime: trip.arrivalTime,
      distanceNm: trip.distanceNm,
      maxSpeedKnots: trip.maxSpeedKnots,
      avgSpeedKnots: trip.avgSpeedKnots,
      notes: trip.notes,
      status: trip.status.name,
    );
  }

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
  final List<TrackPointModel>? trackPoints;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boat_id': boatId,
      'departure_port': departurePort,
      'departure_time': departureTime.toIso8601String(),
      if (arrivalPort != null) 'arrival_port': arrivalPort,
      if (arrivalTime != null) 'arrival_time': arrivalTime!.toIso8601String(),
      if (distanceNm != null) 'distance_nm': distanceNm,
      if (maxSpeedKnots != null) 'max_speed_knots': maxSpeedKnots,
      if (avgSpeedKnots != null) 'avg_speed_knots': avgSpeedKnots,
      if (notes != null) 'notes': notes,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Trip toEntity() {
    return Trip(
      id: id,
      boatId: boatId,
      departurePort: departurePort,
      departureTime: departureTime,
      arrivalPort: arrivalPort,
      arrivalTime: arrivalTime,
      distanceNm: distanceNm,
      maxSpeedKnots: maxSpeedKnots,
      avgSpeedKnots: avgSpeedKnots,
      notes: notes,
      trackPoints: trackPoints
          ?.map((tp) => TrackPoint(
                latitude: tp.latitude,
                longitude: tp.longitude,
                timestamp: tp.timestamp,
                speedKnots: tp.speedKnots,
              ))
          .toList(),
      status: TripStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => TripStatus.completed,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class TrackPointModel {
  const TrackPointModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speedKnots,
  });

  factory TrackPointModel.fromJson(Map<String, dynamic> json) {
    return TrackPointModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      speedKnots: (json['speed_knots'] as num?)?.toDouble(),
    );
  }

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speedKnots;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      if (speedKnots != null) 'speed_knots': speedKnots,
    };
  }
}
