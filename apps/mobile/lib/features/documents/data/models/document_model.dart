import 'package:navis_mobile/features/documents/domain/entities/document.dart';

class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.boatId,
    required this.type,
    required this.expiryDate,
    this.photoUrl,
    this.notes,
    this.alertDaysBefore,
    this.createdAt,
    this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      boatId: json['boat_id'] as String,
      type: json['type'] as String,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      alertDaysBefore: json['alert_days_before'] as int?,
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
      expiryDate: document.expiryDate,
      photoUrl: document.photoUrl,
      notes: document.notes,
      alertDaysBefore: document.alertDaysBefore,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    );
  }

  final String id;
  final String boatId;
  final String type;
  final DateTime expiryDate;
  final String? photoUrl;
  final String? notes;
  final int? alertDaysBefore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boat_id': boatId,
      'type': type,
      'expiry_date': expiryDate.toIso8601String(),
      if (photoUrl != null) 'photo_url': photoUrl,
      if (notes != null) 'notes': notes,
      if (alertDaysBefore != null) 'alert_days_before': alertDaysBefore,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Document toEntity() {
    return Document(
      id: id,
      boatId: boatId,
      type: type,
      expiryDate: expiryDate,
      photoUrl: photoUrl,
      notes: notes,
      alertDaysBefore: alertDaysBefore,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
