class Event {
  const Event({
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

  Event copyWith({
    String? id,
    String? name,
    String? organizer,
    String? organizerLogoUrl,
    String? description,
    String? eventType,
    String? locationName,
    double? latitude,
    double? longitude,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? boatClasses,
    String? registrationUrl,
    String? documentsUrl,
    bool? isFeatured,
    bool? isInterested,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      organizer: organizer ?? this.organizer,
      organizerLogoUrl: organizerLogoUrl ?? this.organizerLogoUrl,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      boatClasses: boatClasses ?? this.boatClasses,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      documentsUrl: documentsUrl ?? this.documentsUrl,
      isFeatured: isFeatured ?? this.isFeatured,
      isInterested: isInterested ?? this.isInterested,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
