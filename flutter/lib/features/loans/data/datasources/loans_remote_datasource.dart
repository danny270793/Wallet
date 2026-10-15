import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/loan_entity.dart';

abstract class LoansRemoteDatasource {
  Future<List<LoanEntity>> getLoans();
  Future<LoanEntity> createLoan({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  });
  Future<LoanEntity> updateLoan({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  });
  Future<void> deleteLoan({required String id});
}

class LoansSupabaseDatasource implements LoansRemoteDatasource {
  final SupabaseClient _client;
  const LoansSupabaseDatasource(this._client);

  @override
  Future<List<LoanEntity>> getLoans() async {
    AppLogger.debug('getLoans called');
    final data = await _client
        .from('wallet_loans')
        .select()
        .isFilter('deletedAt', null)
        .order('createdAt');
    return (data as List)
        .map((e) => LoanEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LoanEntity> createLoan({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) async {
    AppLogger.debug('createLoan called: $name');
    final data = await _client
        .from('wallet_loans')
        .insert({
          'userId': _client.auth.currentUser!.id,
          'accountId': accountId,
          'name': name,
          'value': value,
          'nominalInterestRate': nominalInterestRate,
          'termMonths': termMonths,
          'paymentDay': paymentDay,
          'firstPaymentDate': formatLoanDate(firstPaymentDate),
        })
        .select()
        .single();
    return LoanEntity.fromJson(data);
  }

  @override
  Future<LoanEntity> updateLoan({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) async {
    AppLogger.debug('updateLoan called: $id');
    final data = await _client
        .from('wallet_loans')
        .update({
          'accountId': accountId,
          'name': name,
          'value': value,
          'nominalInterestRate': nominalInterestRate,
          'termMonths': termMonths,
          'paymentDay': paymentDay,
          'firstPaymentDate': formatLoanDate(firstPaymentDate),
        })
        .eq('id', id)
        .select()
        .single();
    return LoanEntity.fromJson(data);
  }

  @override
  Future<void> deleteLoan({required String id}) async {
    AppLogger.debug('deleteLoan called: $id');
    final ok = await _client.rpc<bool>(
      'soft_delete_wallet_loan',
      params: {'p_id': id},
    );
    if (ok != true) {
      throw Exception('soft_delete_wallet_loan: no row updated for $id');
    }
  }
}
