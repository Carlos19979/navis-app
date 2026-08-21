/// One entry in a task's history: the record of a job being carried out.
/// [taskId] is the task it belongs to — every entry has one, bar rows written
/// before the API adopted the loose ones (migration 00042).
class MaintenanceLog {
  const MaintenanceLog({
    required this.id,
    required this.boatId,
    required this.type,
    required this.performedAt,
    this.taskId,
    this.engineHours,
    this.cost,
    this.provider,
    this.notes,
    this.invoiceUrl,
    this.photoUrls = const [],
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> json) {
    return MaintenanceLog(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      taskId: json['task_id'] as String?,
      type: json['type'] as String,
      performedAt: DateTime.parse(json['performed_at'] as String),
      engineHours: (json['engine_hours'] as num?)?.toDouble(),
      cost: (json['cost'] as num?)?.toDouble(),
      provider: json['provider'] as String?,
      notes: json['notes'] as String?,
      invoiceUrl: json['invoice_url'] as String?,
      photoUrls: (json['photo_urls'] as List?)?.cast<String>() ?? const [],
    );
  }

  final String id;
  final String boatId;
  final String? taskId;
  final String type;
  final DateTime performedAt;
  final double? engineHours;
  final double? cost;
  final String? provider;
  final String? notes;
  final String? invoiceUrl;

  /// Service-evidence photos (impeller/anode wear...). Free plan keeps one
  /// per entry; Plus and Pro up to ten — mirrored server-side.
  final List<String> photoUrls;
}

/// Whether a task comes back on a schedule or just happens now and then. It is
/// the only thing the owner picks when creating one, and what decides whether
/// the task can expire at all.
enum MaintenanceKind {
  periodic('periodic'),
  oneOff('one_off');

  const MaintenanceKind(this.api);

  final String api;

  static MaintenanceKind fromApi(String? v) =>
      v == 'one_off' ? MaintenanceKind.oneOff : MaintenanceKind.periodic;
}

/// The server-derived state of a maintenance task. Same vocabulary and same
/// thresholds as a document's expiry (90/30 days), so the two read alike.
enum MaintenanceStatus {
  ok,
  warning,
  critical,
  expired,
  unscheduled; // a one-off job: it has a history, never a date

  static MaintenanceStatus fromApi(String? v) => switch (v) {
        'ok' => MaintenanceStatus.ok,
        'warning' => MaintenanceStatus.warning,
        'critical' => MaintenanceStatus.critical,
        'expired' => MaintenanceStatus.expired,
        _ => MaintenanceStatus.unscheduled,
      };

  /// Whether the task is asking to be done now (or should already have been).
  bool get needsAttention =>
      this == MaintenanceStatus.critical || this == MaintenanceStatus.expired;
}

/// A maintenance job on a boat. A periodic one carries the date it is next due
/// — stored server-side, editable, and rolled forward when the task is marked
/// done, which is what "resetting" an expired task means.
class MaintenanceTask {
  const MaintenanceTask({
    required this.id,
    required this.boatId,
    required this.name,
    required this.kind,
    required this.status,
    this.intervalMonths,
    this.intervalHours,
    this.nextDueDate,
    this.nextDueHours,
    this.lastPerformedAt,
    this.lastEngineHours,
    this.nextDueDays,
    this.hoursUntilDue,
    this.timesDone = 0,
  });

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return MaintenanceTask(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      name: json['name'] as String,
      kind: MaintenanceKind.fromApi(json['kind'] as String?),
      status: MaintenanceStatus.fromApi(json['status'] as String?),
      intervalMonths: (json['interval_months'] as num?)?.toInt(),
      intervalHours: (json['interval_hours'] as num?)?.toDouble(),
      nextDueDate: parseDate(json['next_due_date']),
      nextDueHours: (json['next_due_hours'] as num?)?.toDouble(),
      lastPerformedAt: parseDate(json['last_performed_at']),
      lastEngineHours: (json['last_engine_hours'] as num?)?.toDouble(),
      nextDueDays: (json['next_due_days'] as num?)?.toInt(),
      hoursUntilDue: (json['hours_until_due'] as num?)?.toDouble(),
      timesDone: (json['times_done'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String boatId;
  final String name;
  final MaintenanceKind kind;
  final MaintenanceStatus status;
  final int? intervalMonths;
  final double? intervalHours;
  final DateTime? nextDueDate;
  final double? nextDueHours;
  final DateTime? lastPerformedAt;
  final double? lastEngineHours;
  final int? nextDueDays;
  final double? hoursUntilDue;
  final int timesDone;

  bool get isPeriodic => kind == MaintenanceKind.periodic;
}

/// A cost associated with a boat.
class Expense {
  const Expense({
    required this.id,
    required this.boatId,
    required this.category,
    required this.amount,
    required this.incurredOn,
    this.notes,
    this.invoiceUrl,
    this.liters,
    this.pricePerLiter,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      incurredOn: DateTime.parse(json['incurred_on'] as String),
      notes: json['notes'] as String?,
      invoiceUrl: json['invoice_url'] as String?,
      liters: (json['liters'] as num?)?.toDouble(),
      pricePerLiter: (json['price_per_liter'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String boatId;
  final String category;
  final double amount;
  final DateTime incurredOn;
  final String? notes;
  final String? invoiceUrl;

  /// Litres (fuel expenses only); null otherwise.
  final double? liters;

  /// Server-derived €/L (amount/liters); null unless both are present.
  final double? pricePerLiter;
}

/// Aggregated expense totals per category.
class ExpenseSummary {
  const ExpenseSummary({required this.totals, required this.total});

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['totals'] as Map<String, dynamic>?) ?? {};
    return ExpenseSummary(
      totals: raw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }

  final Map<String, double> totals;
  final double total;
}
