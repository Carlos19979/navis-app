/// A maintenance/service record for a boat. [taskId] links it to a recurring
/// task; null = a one-off entry.
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
}

/// The derived due-state of a maintenance task, mirroring the server.
enum MaintenanceStatus {
  ok,
  dueSoon,
  overdue,
  pending, // has an interval, never logged
  none; // history-only (no interval)

  static MaintenanceStatus fromApi(String? v) => switch (v) {
        'ok' => MaintenanceStatus.ok,
        'due_soon' => MaintenanceStatus.dueSoon,
        'overdue' => MaintenanceStatus.overdue,
        'pending' => MaintenanceStatus.pending,
        _ => MaintenanceStatus.none,
      };
}

/// A recurring maintenance task (a boat component with its own service interval)
/// plus its server-derived due-state.
class MaintenanceTask {
  const MaintenanceTask({
    required this.id,
    required this.boatId,
    required this.name,
    required this.status,
    this.intervalMonths,
    this.intervalHours,
    this.lastPerformedAt,
    this.lastEngineHours,
    this.nextDueDate,
    this.nextDueDays,
    this.hoursUntilDue,
  });

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return MaintenanceTask(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      name: json['name'] as String,
      status: MaintenanceStatus.fromApi(json['status'] as String?),
      intervalMonths: (json['interval_months'] as num?)?.toInt(),
      intervalHours: (json['interval_hours'] as num?)?.toDouble(),
      lastPerformedAt: parseDate(json['last_performed_at']),
      lastEngineHours: (json['last_engine_hours'] as num?)?.toDouble(),
      nextDueDate: parseDate(json['next_due_date']),
      nextDueDays: (json['next_due_days'] as num?)?.toInt(),
      hoursUntilDue: (json['hours_until_due'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String boatId;
  final String name;
  final MaintenanceStatus status;
  final int? intervalMonths;
  final double? intervalHours;
  final DateTime? lastPerformedAt;
  final double? lastEngineHours;
  final DateTime? nextDueDate;
  final int? nextDueDays;
  final double? hoursUntilDue;

  bool get hasInterval => intervalMonths != null || intervalHours != null;
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
    );
  }

  final String id;
  final String boatId;
  final String category;
  final double amount;
  final DateTime incurredOn;
  final String? notes;
  final String? invoiceUrl;
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
