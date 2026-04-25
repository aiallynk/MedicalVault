class MedicalVerification {
  final String status;
  final String label;
  final String method;
  final String reason;
  final String confidence;

  const MedicalVerification({
    this.status = 'pending',
    this.label = 'UNKNOWN',
    this.method = 'inconclusive',
    this.reason = '',
    this.confidence = 'unknown',
  });

  factory MedicalVerification.fromApi(dynamic raw) {
    if (raw is! Map) return const MedicalVerification();
    return MedicalVerification(
      status: (raw['status'] ?? 'pending').toString(),
      label: (raw['label'] ?? 'UNKNOWN').toString(),
      method: (raw['method'] ?? 'inconclusive').toString(),
      reason: (raw['reason'] ?? '').toString(),
      confidence: (raw['confidence'] ?? 'unknown').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'label': label,
      'method': method,
      'reason': reason,
      'confidence': confidence,
    };
  }

  bool get isVerified =>
      status.toLowerCase() == 'verified' && label.toUpperCase() == 'MEDICAL';

  bool get isAccepted =>
      status.toLowerCase() == 'accepted' && label.toUpperCase() == 'MEDICAL';

  bool get hasSignal => isVerified || isAccepted;
}

class Document {
  final String? id;
  final String? patientId;
  final String? userId; // backward compatibility
  final String? title;
  final String? description;
  final String? notes;
  final String? date;
  final String? fileName;
  final String? fileType;
  final String? url; // S3 signed URL or backend/local file URL
  final String? category; // Logical grouping
  final String? type; // Backend sometimes uses this
  final String? s3Key; // S3 key for backend operations
  final bool? medicalVerified;
  final MedicalVerification? medicalVerification;

  Document({
    this.id,
    this.patientId,
    this.userId,
    this.title,
    this.description,
    this.notes,
    this.date,
    this.fileName,
    this.fileType,
    this.url,
    this.category,
    this.type,
    this.s3Key,
    this.medicalVerified,
    this.medicalVerification,
  });

  factory Document.fromApi(Map<String, dynamic> json) {
    final resolvedUrl = json['url'];
    final rawType = (json['type'] ?? json['category'] ?? "")
        .toString()
        .toLowerCase()
        .trim();

    String normalized;
    if (rawType.contains("report")) {
      normalized = "report";
    } else if (rawType.contains("prescription")) {
      normalized = "prescription";
    } else if (rawType.contains("bill")) {
      normalized = "bill";
    } else if (rawType.contains("insurance")) {
      normalized = "insurance";
    } else {
      normalized = "report";
    }

    final verification =
        MedicalVerification.fromApi(json['medicalVerification']);
    final verified = json['medicalVerified'] == true ||
        json['isMedicalVerified'] == true ||
        verification.isVerified;

    return Document(
      id: json['id'] ?? json['_id'],
      patientId: json['patientId'] ?? json['userId'],
      userId: json['userId'],
      title: json['title'] ??
          json['fileName'] ??
          json['originalName'] ??
          'Untitled',
      description: json['description'],
      notes: json['notes'],
      date: json['date'] ?? json['uploadedAt'],
      fileName: json['fileName'] ?? json['originalName'],
      fileType: json['fileType'] ?? json['mimeType'],
      url: resolvedUrl,
      category: normalized,
      type: normalized,
      s3Key: json['s3Key'],
      medicalVerified: verified,
      medicalVerification:
          json['medicalVerification'] is Map ? verification : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "patientId": patientId,
      "userId": userId,
      "title": title,
      "description": description,
      "notes": notes,
      "date": date,
      "fileName": fileName,
      "fileType": fileType,
      "url": url,
      "category": category,
      "type": type,
      "s3Key": s3Key,
      "medicalVerified": medicalVerified,
      "medicalVerification": medicalVerification?.toJson(),
    };
  }

  String get normalizedType {
    return (type ?? category ?? "").toLowerCase();
  }

  bool get isMedicalVerified =>
      medicalVerified == true || (medicalVerification?.isVerified ?? false);

  bool get hasMedicalVerification =>
      isMedicalVerified || (medicalVerification?.hasSignal ?? false);
}
