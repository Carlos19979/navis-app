import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';

/// Maps the trip JSON envelope (shared by the server) into regatta entities.
class RegattaModel {
  static Regatta fromJson(Map<String, dynamic> json) {
    return Regatta(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      groupId: json['group_id'] as String?,
      title: json['title'] as String?,
      kind: json['kind'] as String? ?? 'trip',
      status: json['status'] as String,
      departurePort: json['departure_port'] as String,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      checklistCompleted: json['checklist_completed_at'] != null,
    );
  }
}

class ChecklistItemModel {
  static ChecklistItem fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      label: json['label'] as String,
      isChecked: json['is_checked'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
    );
  }
}

class RegattaParticipantModel {
  static RegattaParticipant fromJson(Map<String, dynamic> json) {
    return RegattaParticipant(
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      rsvp: json['rsvp'] as String,
    );
  }
}
