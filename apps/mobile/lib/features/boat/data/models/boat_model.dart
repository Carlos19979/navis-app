import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';

class BoatModel {
  const BoatModel({
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
    this.permissions = const BoatPermissions(),
    this.createdAt,
    this.updatedAt,
  });

  factory BoatModel.fromJson(Map<String, dynamic> json) {
    return BoatModel(
      id: json['id'] as String,
      name: json['name'] as String,
      registration: json['registration'] as String,
      type: json['type'] as String,
      lengthMeters: (json['length_m'] as num).toDouble(),
      homePort: json['home_port'] as String?,
      homePortLat: (json['home_port_lat'] as num?)?.toDouble(),
      homePortLon: (json['home_port_lon'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      ownerId: json['owner_id'] as String?,
      isOwner: json['is_owner'] as bool? ?? true,
      permissions: json['permissions'] is Map<String, dynamic>
          ? BoatPermissions.fromJson(
              json['permissions'] as Map<String, dynamic>)
          : const BoatPermissions(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  factory BoatModel.fromEntity(Boat boat) {
    return BoatModel(
      id: boat.id,
      name: boat.name,
      registration: boat.registration,
      type: boat.type,
      lengthMeters: boat.lengthMeters,
      homePort: boat.homePort,
      homePortLat: boat.homePortLat,
      homePortLon: boat.homePortLon,
      photoUrl: boat.photoUrl,
      ownerId: boat.ownerId,
      createdAt: boat.createdAt,
      updatedAt: boat.updatedAt,
    );
  }

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
  final BoatPermissions permissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'registration': registration,
      'type': type,
      'length_m': lengthMeters,
      'home_port': homePort,
      if (homePortLat != null) 'home_port_lat': homePortLat,
      if (homePortLon != null) 'home_port_lon': homePortLon,
      'photo_url': photoUrl,
      'owner_id': ownerId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Boat toEntity() {
    return Boat(
      id: id,
      name: name,
      registration: registration,
      type: type,
      lengthMeters: lengthMeters,
      homePort: homePort,
      homePortLat: homePortLat,
      homePortLon: homePortLon,
      photoUrl: photoUrl,
      ownerId: ownerId,
      isOwner: isOwner,
      permissions: permissions,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
