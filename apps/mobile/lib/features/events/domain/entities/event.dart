class Event {
  const Event({
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

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    DateTime? endDate,
    String? location,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? organizerName,
    bool? isRegistered,
    int? maxParticipants,
    int? currentParticipants,
    DateTime? createdAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      organizerName: organizerName ?? this.organizerName,
      isRegistered: isRegistered ?? this.isRegistered,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
