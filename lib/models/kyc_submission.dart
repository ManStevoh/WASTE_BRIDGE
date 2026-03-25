/// Row from `GET /kyc/submissions` (`KycSubmission::toClientArray`).
class KycSubmission {
  const KycSubmission({
    required this.publicId,
    required this.status,
    required this.documentType,
    this.createdAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String publicId;
  final String status;
  final String documentType;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  factory KycSubmission.fromJson(Map<String, dynamic> json) {
    return KycSubmission(
      publicId: json['publicId'] as String,
      status: json['status'] as String,
      documentType: json['documentType'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.tryParse(json['reviewedAt'] as String),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}
