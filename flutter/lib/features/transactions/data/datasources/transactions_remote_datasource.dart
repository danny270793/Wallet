import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/transaction_entity.dart';

abstract class TransactionsRemoteDatasource {
  /// [monthStartLocal] normalized to local calendar day 1; range is \[start local, next month local).
  Future<List<TransactionEntity>> getTransactionsForMonth(DateTime monthStartLocal);

  /// [yearStartLocal] normalized to Jan 1 local; range is \[Jan 1, Jan 1 next year).
  Future<List<TransactionEntity>> getTransactionsForYear(DateTime yearStartLocal);

  /// All-time search on [description] (case-insensitive substring). RLS limits to current user.
  Future<List<TransactionEntity>> searchTransactionsByDescription(String query, {int limit = 200});
  Future<TransactionEntity> createTransaction({
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
    String? transferGroupId,
    String? creditGroupId,
  });
  Future<TransactionEntity> updateTransaction({
    required String id,
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
    String? transferGroupId,
    String? creditGroupId,
  });
  Future<void> deleteTransaction({required String id});
}

class TransactionsSupabaseDatasource implements TransactionsRemoteDatasource {
  final SupabaseClient _client;
  const TransactionsSupabaseDatasource(this._client);

  /// Embeds FK `name` fields for list display (PostgREST nested select).
  static const _transactionSelectEmbedded = '''
*,
wallet_accounts(name),
wallet_cards(name),
wallet_categories(name),
wallet_tags(name)
''';

  @override
  Future<List<TransactionEntity>> getTransactionsForMonth(DateTime monthStartLocal) async {
    final y = monthStartLocal.year;
    final m = monthStartLocal.month;
    final startLocal = DateTime(y, m, 1);
    final endExclusiveLocal = DateTime(y, m + 1, 1);
    final startUtc = startLocal.toUtc().toIso8601String();
    final endUtc = endExclusiveLocal.toUtc().toIso8601String();
    AppLogger.debug('getTransactionsForMonth utc: $startUtc .. $endUtc');
    final data = await _client
        .from('wallet_transactions')
        .select(_transactionSelectEmbedded)
        .isFilter('deletedAt', null)
        .gte('transactedAt', startUtc)
        .lt('transactedAt', endUtc)
        .order('transactedAt', ascending: false);
    return (data as List).map((e) => TransactionEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<TransactionEntity>> getTransactionsForYear(DateTime yearStartLocal) async {
    final y = yearStartLocal.year;
    final startLocal = DateTime(y, 1, 1);
    final endExclusiveLocal = DateTime(y + 1, 1, 1);
    final startUtc = startLocal.toUtc().toIso8601String();
    final endUtc = endExclusiveLocal.toUtc().toIso8601String();
    AppLogger.debug('getTransactionsForYear utc: $startUtc .. $endUtc');
    final data = await _client
        .from('wallet_transactions')
        .select(_transactionSelectEmbedded)
        .isFilter('deletedAt', null)
        .gte('transactedAt', startUtc)
        .lt('transactedAt', endUtc)
        .order('transactedAt', ascending: false);
    return (data as List).map((e) => TransactionEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<TransactionEntity>> searchTransactionsByDescription(String query, {int limit = 200}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final escaped = q.replaceAll('\\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    AppLogger.debug('searchTransactionsByDescription: ${q.length} chars');
    final data = await _client
        .from('wallet_transactions')
        .select(_transactionSelectEmbedded)
        .isFilter('deletedAt', null)
        .ilike('description', pattern)
        .order('transactedAt', ascending: false)
        .limit(limit);
    return (data as List).map((e) => TransactionEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<TransactionEntity> createTransaction({
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
    String? transferGroupId,
    String? creditGroupId,
  }) async {
    AppLogger.debug('createTransaction called');
    final row = <String, dynamic>{
      'userId': _client.auth.currentUser!.id,
      'transactedAt': transactedAt.toUtc().toIso8601String(),
      'value': value,
      'ignore': ignore,
      'percentage': percentage,
      if (accountId != null) 'accountId': accountId,
      if (cardId != null) 'cardId': cardId,
      if (categoryId != null) 'categoryId': categoryId,
      if (tagId != null) 'tagId': tagId,
      if (description != null) 'description': description,
      if (transferGroupId != null) 'transferGroupId': transferGroupId,
      if (creditGroupId != null) 'creditGroupId': creditGroupId,
    };
    final data = await _client.from('wallet_transactions').insert(row).select(_transactionSelectEmbedded).single();
    return TransactionEntity.fromJson(data);
  }

  @override
  Future<TransactionEntity> updateTransaction({
    required String id,
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
    String? transferGroupId,
    String? creditGroupId,
  }) async {
    AppLogger.debug('updateTransaction called: $id');
    final data = await _client
        .from('wallet_transactions')
        .update({
          'accountId': accountId,
          'cardId': cardId,
          'categoryId': categoryId,
          'tagId': tagId,
          'description': description,
          'transactedAt': transactedAt.toUtc().toIso8601String(),
          'value': value,
          'ignore': ignore,
          'percentage': percentage,
          'transferGroupId': transferGroupId,
          'creditGroupId': creditGroupId,
        })
        .eq('id', id)
        .select(_transactionSelectEmbedded)
        .single();
    return TransactionEntity.fromJson(data);
  }

  @override
  Future<void> deleteTransaction({required String id}) async {
    AppLogger.debug('deleteTransaction called: $id');
    final ok = await _client.rpc<bool>(
      'soft_delete_wallet_transaction',
      params: {'p_id': id},
    );
    if (ok != true) {
      throw Exception('soft_delete_wallet_transaction: no row updated for $id');
    }
  }
}
