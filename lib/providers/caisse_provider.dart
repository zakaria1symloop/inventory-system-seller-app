import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/api_service.dart';
import '../data/models/caisse_model.dart';
import '../data/models/caisse_transaction_model.dart';

// My caisse provider
final myCaisseProvider = FutureProvider<CaisseModel?>((ref) async {
  try {
    final response = await ApiService.instance.getMyCaisse();
    final data = response.data;
    if (data != null && data['caisse'] != null) {
      return CaisseModel.fromJson(data['caisse']);
    }
    return null;
  } catch (e) {
    return null;
  }
});

// Recent transactions from myCaisse endpoint
final myRecentTransactionsProvider = FutureProvider<List<CaisseTransactionModel>>((ref) async {
  try {
    final response = await ApiService.instance.getMyCaisse();
    final data = response.data;
    if (data != null && data['recent_transactions'] != null) {
      final List txList = data['recent_transactions'];
      return txList.map((tx) => CaisseTransactionModel.fromJson(tx)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// Paginated transactions provider
final caisseTransactionsProvider = FutureProvider.family<List<CaisseTransactionModel>, Map<String, dynamic>>((ref, params) async {
  try {
    final caisseId = params['caisse_id'] as int;
    final page = params['page'] as int? ?? 1;
    final type = params['type'] as String?;
    final response = await ApiService.instance.getCaisseTransactions(caisseId, page: page, type: type);
    final data = response.data;
    final List txList = data is Map ? (data['data'] ?? []) : [];
    return txList.map((tx) => CaisseTransactionModel.fromJson(tx)).toList();
  } catch (e) {
    return [];
  }
});
