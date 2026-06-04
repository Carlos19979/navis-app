/// A group regatta/outing. Backed by the trips table on the server, so it shares
/// the GPS/logbook lifecycle (planned -> recording -> completed / cancelled).
class Regatta {
  const Regatta({
    required this.id,
    required this.boatId,
    required this.ownerId,
    required this.kind,
    required this.status,
    required this.departurePort,
    this.groupId,
    this.title,
    this.scheduledAt,
    this.checklistCompleted = false,
  });

  final String id;
  final String boatId;
  final String ownerId;
  final String? groupId;
  final String? title;
  final String kind; // 'trip' | 'regatta'
  final String status; // planned | recording | completed | cancelled
  final String departurePort;
  final DateTime? scheduledAt;
  final bool checklistCompleted;

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : departurePort;

  bool get isPlanned => status == 'planned';
  bool get isRecording => status == 'recording';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Regatta && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A single safety-checklist entry for a trip/regatta.
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.label,
    required this.isChecked,
    required this.position,
  });

  final String id;
  final String label;
  final bool isChecked;
  final int position;

  ChecklistItem copyWith({bool? isChecked}) => ChecklistItem(
        id: id,
        label: label,
        isChecked: isChecked ?? this.isChecked,
        position: position,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A participant's RSVP to a planned regatta.
class RegattaParticipant {
  const RegattaParticipant({required this.userId, required this.rsvp});

  final String userId;
  final String rsvp; // going | maybe | not_going
}
