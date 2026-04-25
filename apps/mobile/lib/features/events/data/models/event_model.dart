import 'package:navis_mobile/features/events/domain/entities/event.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.endDate,
    this.location,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.organizerName,
    this.isRegistered = false,
    this.maxParticipants,
    this.currentParticipants,
    this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      organizerName: json['organizer_name'] as String?,
      isRegistered: json['is_registered'] as bool? ?? false,
      maxParticipants: json['max_participants'] as int?,
      currentParticipants: json['current_participants'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? endDate;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? organizerName;
  final bool isRegistered;
  final int? maxParticipants;
  final int? currentParticipants;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageUrl != null) 'image_url': imageUrl,
      if (organizerName != null) 'organizer_name': organizerName,
      'is_registered': isRegistered,
      if (maxParticipants != null) 'max_participants': maxParticipants,
      if (currentParticipants != null) 'current_participants': currentParticipants,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Event toEntity() {
    return Event(
      id: id,
      title: title,
      description: description,
      date: date,
      endDate: endDate,
      location: location,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      organizerName: organizerName,
      isRegistered: isRegistered,
      maxParticipants: maxParticipants,
      currentParticipants: currentParticipants,
      createdAt: createdAt,
    );
  }
}
