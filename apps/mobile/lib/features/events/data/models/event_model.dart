import 'package:navis_mobile/features/events/domain/entities/event.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.name,
    required this.organizer,
    required this.eventType,
    required this.locationName,
    required this.startDate,
    this.organizerLogoUrl,
    this.description,
    this.endDate,
    this.latitude,
    this.longitude,
    this.boatClasses = const [],
    this.registrationUrl,
    this.documentsUrl,
    this.isFeatured = false,
    this.isInterested = false,
    this.createdAt,
    this.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      name: json['name'] as String,
      organizer: json['organizer'] as String,
      organizerLogoUrl: json['organizer_logo_url'] as String?,
      description: json['description'] as String?,
      eventType: json['event_type'] as String,
      locationName: json['location_name'] as String,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      boatClasses: (json['boat_classes'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      registrationUrl: json['registration_url'] as String?,
      documentsUrl: json['documents_url'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      isInterested: json['is_interested'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String organizer;
  final String? organizerLogoUrl;
  final String? description;
  final String eventType;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> boatClasses;
  final String? registrationUrl;
  final String? documentsUrl;
  final bool isFeatured;
  final bool isInterested;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Event toEntity() {
    return Event(
      id: id,
      name: name,
      organizer: organizer,
      organizerLogoUrl: organizerLogoUrl,
      description: description,
      eventType: eventType,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      startDate: startDate,
      endDate: endDate,
      boatClasses: boatClasses,
      registrationUrl: registrationUrl,
      documentsUrl: documentsUrl,
      isFeatured: isFeatured,
      isInterested: isInterested,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
