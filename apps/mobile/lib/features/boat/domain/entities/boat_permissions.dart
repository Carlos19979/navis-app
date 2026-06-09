/// Granular permission set for the current user on a (possibly shared) boat.
/// Defaults to all-true so the owner and loading states fail open.
class BoatPermissions {
  const BoatPermissions({
    this.canRecordTrips = true,
    this.canManageExpenses = true,
    this.canManageMaintenance = true,
    this.canViewDocuments = true,
    this.canManageDocuments = true,
  });

  factory BoatPermissions.fromJson(Map<String, dynamic> json) {
    return BoatPermissions(
      canRecordTrips: json['can_record_trips'] as bool? ?? true,
      canManageExpenses: json['can_manage_expenses'] as bool? ?? true,
      canManageMaintenance: json['can_manage_maintenance'] as bool? ?? true,
      canViewDocuments: json['can_view_documents'] as bool? ?? true,
      canManageDocuments: json['can_manage_documents'] as bool? ?? true,
    );
  }

  final bool canRecordTrips;
  final bool canManageExpenses;
  final bool canManageMaintenance;
  final bool canViewDocuments;
  final bool canManageDocuments;

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
}
