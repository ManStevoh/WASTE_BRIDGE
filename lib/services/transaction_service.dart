import 'dart:async';

import 'package:waste_bridge/models/app_transaction.dart';
import 'package:waste_bridge/services/mock_data.dart';

class TransactionService {
  Future<List<AppTransaction>> getTransactions() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<AppTransaction>.from(MockData.transactions);
  }
}
