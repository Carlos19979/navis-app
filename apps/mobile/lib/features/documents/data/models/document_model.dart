import 'package:navis_mobile/features/documents/domain/entities/document.dart';

class DocumentModel {
  const DocumentModel({
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

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final alertDays = (json['alert_days'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    return DocumentModel(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      type: json['type'] as String,
      customName: json['custom_name'] as String?,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      alertDays: alertDays,
      alertDaysBefore: alertDays != null
          ? (alertDays.isNotEmpty ? alertDays.first : null)
          : json['alert_days_before'] as int?,
      lastRenewalDate: json['last_renewal_date'] != null
          ? DateTime.parse(json['last_renewal_date'] as String)
          : null,
      lastRenewalCost: json['last_renewal_cost'] != null
          ? (json['last_renewal_cost'] as num).toDouble()
          : null,
      lastRenewalProvider: json['last_renewal_provider'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  factory DocumentModel.fromEntity(Document document) {
    return DocumentModel(
      id: document.id,
      boatId: document.boatId,
      type: document.type,
      customName: document.customName,
      expiryDate: document.expiryDate,
      photoUrl: document.photoUrl,
      notes: document.notes,
      alertDaysBefore: document.alertDaysBefore,
      alertDays: document.alertDays,
      lastRenewalDate: document.lastRenewalDate,
      lastRenewalCost: document.lastRenewalCost,
      lastRenewalProvider: document.lastRenewalProvider,
      status: document.status,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    );
  }

  final String id;
  final String boatId;
  final String type;
  final String? customName;
  final DateTime expiryDate;
  final String? photoUrl;
  final String? notes;
  final int? alertDaysBefore;
  final List<int>? alertDays;
  final DateTime? lastRenewalDate;
  final double? lastRenewalCost;
  final String? lastRenewalProvider;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boat_id': boatId,
      'type': type,
      if (customName != null) 'custom_name': customName,
      'expiry_date': expiryDate.toUtc().toIso8601String(),
      if (photoUrl != null) 'photo_url': photoUrl,
      if (notes != null) 'notes': notes,
      if (alertDays != null && alertDays!.isNotEmpty)
        'alert_days': alertDays
      else if (alertDaysBefore != null)
        'alert_days': [alertDaysBefore],
      if (lastRenewalDate != null)
        'last_renewal_date': lastRenewalDate!.toUtc().toIso8601String(),
      if (lastRenewalCost != null) 'last_renewal_cost': lastRenewalCost,
      if (lastRenewalProvider != null)
        'last_renewal_provider': lastRenewalProvider,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Document toEntity() {
    return Document(
      id: id,
      boatId: boatId,
      type: type,
      customName: customName,
      expiryDate: expiryDate,
      photoUrl: photoUrl,
      notes: notes,
      alertDaysBefore: alertDaysBefore,
      alertDays: alertDays,
      lastRenewalDate: lastRenewalDate,
      lastRenewalCost: lastRenewalCost,
      lastRenewalProvider: lastRenewalProvider,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
