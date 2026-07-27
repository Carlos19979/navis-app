/// Granular permission set for a user on a (possibly shared) boat. Mirrors the
/// five flags the API enforces on its write paths: trips, documents (view and
/// manage), maintenance and expenses.
///
/// Defaults are **all false**. The API denies by default too
/// (`boat_members.can_record_trips DEFAULT false`), and a client that guesses
/// "allowed" is exactly what let a user record a whole trip and then lose it to
/// a 403 on save. Use [BoatPermissions.all] where full access is a fact — the
/// owner — never as a fallback for "we don't know yet".
class BoatPermissions {
  const BoatPermissions({
    this.canRecordTrips = false,
    this.canManageExpenses = false,
    this.canManageMaintenance = false,
    this.canViewDocuments = false,
    this.canManageDocuments = false,
  });

  /// Everything granted. The owner's permission set (the API answers the same
  /// for owners, see `domain.OwnerPermissions`).
  const BoatPermissions.all()
      : canRecordTrips = true,
        canManageExpenses = true,
        canManageMaintenance = true,
        canViewDocuments = true,
        canManageDocuments = true;

  /// Nothing granted — a fresh member (joins as *viewer*) or an unknown
  /// permission set that has not resolved yet. Named so call sites read as a
  /// deliberate choice rather than "I forgot to pass anything".
  const BoatPermissions.none() : this();

  /// Missing keys read as "not granted": the server always sends all five, so
  /// an absent flag means an older/unknown payload, not a permission.
  factory BoatPermissions.fromJson(Map<String, dynamic> json) {
    return BoatPermissions(
      canRecordTrips: json['can_record_trips'] as bool? ?? false,
      canManageExpenses: json['can_manage_expenses'] as bool? ?? false,
      canManageMaintenance: json['can_manage_maintenance'] as bool? ?? false,
      canViewDocuments: json['can_view_documents'] as bool? ?? false,
      canManageDocuments: json['can_manage_documents'] as bool? ?? false,
    );
  }

  final bool canRecordTrips;
  final bool canManageExpenses;
  final bool canManageMaintenance;
  final bool canViewDocuments;
  final bool canManageDocuments;

  /// How many of the five areas are granted (owner-facing member summary).
  int get grantedCount =>
      BoatPermissionArea.values.where((area) => area.isGrantedIn(this)).length;

  Map<String, dynamic> toJson() => {
        'can_record_trips': canRecordTrips,
        'can_manage_expenses': canManageExpenses,
        'can_manage_maintenance': canManageMaintenance,
        'can_view_documents': canViewDocuments,
        'can_manage_documents': canManageDocuments,
      };

  BoatPermissions copyWith({
    bool? canRecordTrips,
    bool? canManageExpenses,
    bool? canManageMaintenance,
    bool? canViewDocuments,
    bool? canManageDocuments,
  }) {
    return BoatPermissions(
      canRecordTrips: canRecordTrips ?? this.canRecordTrips,
      canManageExpenses: canManageExpenses ?? this.canManageExpenses,
      canManageMaintenance: canManageMaintenance ?? this.canManageMaintenance,
      canViewDocuments: canViewDocuments ?? this.canViewDocuments,
      canManageDocuments: canManageDocuments ?? this.canManageDocuments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoatPermissions &&
          runtimeType == other.runtimeType &&
          canRecordTrips == other.canRecordTrips &&
          canManageExpenses == other.canManageExpenses &&
          canManageMaintenance == other.canManageMaintenance &&
          canViewDocuments == other.canViewDocuments &&
          canManageDocuments == other.canManageDocuments;

  @override
  int get hashCode => Object.hash(
        canRecordTrips,
        canManageExpenses,
        canManageMaintenance,
        canViewDocuments,
        canManageDocuments,
      );

  @override
  String toString() => 'BoatPermissions(${toJson()})';
}

/// One area of a boat the owner can grant or withhold, so a screen can ask
/// "may I do this?" without hard-coding which flag guards it.
///
/// The order matches the owner-facing permission editor.
enum BoatPermissionArea {
  recordTrips,
  viewDocuments,
  manageDocuments,
  manageMaintenance,
  manageExpenses;

  /// Whether [permissions] grants this area.
  bool isGrantedIn(BoatPermissions permissions) => switch (this) {
        BoatPermissionArea.recordTrips => permissions.canRecordTrips,
        BoatPermissionArea.viewDocuments => permissions.canViewDocuments,
        BoatPermissionArea.manageDocuments => permissions.canManageDocuments,
        BoatPermissionArea.manageMaintenance =>
          permissions.canManageMaintenance,
        BoatPermissionArea.manageExpenses => permissions.canManageExpenses,
      };
}
