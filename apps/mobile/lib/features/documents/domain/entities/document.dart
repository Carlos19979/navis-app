class Document {
  const Document({
    required this.id,
    required this.boatId,
    required this.type,
    required this.expiryDate,
    this.customName,
    this.photoUrl,
    this.notes,
    this.alertDaysBefore,
    this.alertDays,
    this.lastRenewalDate,
    this.lastRenewalCost,
    this.lastRenewalProvider,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String boatId;
  final String type;

  /// User-given name when [type] is `custom`.
  final String? customName;
  final DateTime expiryDate;
  final String? photoUrl;
  final String? notes;

  /// First (largest) alert threshold — kept for callers that only need one.
  final int? alertDaysBefore;

  /// Full list of alert thresholds (days before expiry), e.g. [30, 7].
  final List<int>? alertDays;
  final DateTime? lastRenewalDate;
  final double? lastRenewalCost;
  final String? lastRenewalProvider;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Document copyWith({
    String? id,
    String? boatId,
    String? type,
    String? customName,
    DateTime? expiryDate,
    String? photoUrl,
    String? notes,
    int? alertDaysBefore,
    List<int>? alertDays,
    DateTime? lastRenewalDate,
    double? lastRenewalCost,
    String? lastRenewalProvider,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id ?? this.id,
      boatId: boatId ?? this.boatId,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      expiryDate: expiryDate ?? this.expiryDate,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      alertDaysBefore: alertDaysBefore ?? this.alertDaysBefore,
      alertDays: alertDays ?? this.alertDays,
      lastRenewalDate: lastRenewalDate ?? this.lastRenewalDate,
      lastRenewalCost: lastRenewalCost ?? this.lastRenewalCost,
      lastRenewalProvider: lastRenewalProvider ?? this.lastRenewalProvider,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Document &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          boatId == other.boatId &&
          type == other.type &&
          expiryDate == other.expiryDate &&
          lastRenewalDate == other.lastRenewalDate &&
          lastRenewalCost == other.lastRenewalCost &&
          lastRenewalProvider == other.lastRenewalProvider &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        id,
        boatId,
        type,
        expiryDate,
        lastRenewalDate,
        lastRenewalCost,
        lastRenewalProvider,
        status,
      );
}
