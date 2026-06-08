/// A maintenance/service record for a boat.
class MaintenanceLog {
  const MaintenanceLog({
    required this.id,
    required this.boatId,
    required this.type,
    required this.performedAt,
    this.engineHours,
    this.cost,
    this.provider,
    this.notes,
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> json) {
    return MaintenanceLog(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      type: json['type'] as String,
      performedAt: DateTime.parse(json['performed_at'] as String),
      engineHours: (json['engine_hours'] as num?)?.toDouble(),
      cost: (json['cost'] as num?)?.toDouble(),
      provider: json['provider'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String boatId;
  final String type;
  final DateTime performedAt;
  final double? engineHours;
  final double? cost;
  final String? provider;
  final String? notes;
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
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      incurredOn: DateTime.parse(json['incurred_on'] as String),
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String boatId;
  final String category;
  final double amount;
  final DateTime incurredOn;
  final String? notes;
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
