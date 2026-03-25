/// Response from `GET /wallet` / `GET /user/wallet`.
class WalletSnapshot {
  const WalletSnapshot({
    required this.publicId,
    required this.balance,
    required this.currency,
  });

  final String publicId;
  final double balance;
  final String currency;

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) {
    return WalletSnapshot(
      publicId: json['publicId'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'KES',
    );
  }
}
