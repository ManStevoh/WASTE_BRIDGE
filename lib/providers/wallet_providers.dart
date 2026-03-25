import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/wallet_snapshot.dart';
import 'package:waste_bridge/providers/service_providers.dart';

/// Server wallet balance (`GET /wallet`).
final walletBalanceProvider =
    FutureProvider.autoDispose<WalletSnapshot>((ref) {
  return ref.watch(transactionServiceProvider).getWallet();
});
