class Document {
  const Document({
    required this.id,
    required this.boatId,
    required this.type,
    required this.expiryDate,
    this.photoUrl,
    this.notes,
    this.alertDaysBefore,
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
  final DateTime expiryDate;
  final String? photoUrl;
  final String? notes;
  final int? alertDaysBefore;
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
    DateTime? expiryDate,
    String? photoUrl,
    String? notes,
    int? alertDaysBefore,
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
      expiryDate: expiryDate ?? this.expiryDate,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      alertDaysBefore: alertDaysBefore ?? this.alertDaysBefore,
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
