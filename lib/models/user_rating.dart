/// Row from `GET /users/{userPublicId}/ratings`.
class UserRating {
  const UserRating({
    required this.score,
    this.comment,
    this.createdAt,
    this.raterName,
    this.raterPublicId,
    this.pickupRequestId,
  });

  final double score;
  final String? comment;
  final DateTime? createdAt;
  final String? raterName;
  final String? raterPublicId;
  final String? pickupRequestId;

  factory UserRating.fromJson(Map<String, dynamic> json) {
    final rater = json['rater'];
    String? raterName;
    String? raterPublicId;
    if (rater is Map<String, dynamic>) {
      raterName = rater['name'] as String?;
      raterPublicId = rater['id'] as String?;
    }
    return UserRating(
      score: (json['score'] as num).toDouble(),
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      raterName: raterName,
      raterPublicId: raterPublicId,
      pickupRequestId: json['pickupRequestId'] as String?,
    );
  }
}
