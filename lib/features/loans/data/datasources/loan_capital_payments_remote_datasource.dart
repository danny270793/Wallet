import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/loan_capital_payment_entity.dart';
import '../../domain/entities/loan_entity.dart';

abstract class LoanCapitalPaymentsRemoteDatasource {
  Future<List<LoanCapitalPaymentEntity>> getCapitalPayments();
  Future<LoanCapitalPaymentEntity> createCapitalPayment({
    required String loanId,
    required double value,
    required DateTime paidAt,
  });
  Future<void> deleteCapitalPayment({required String id});
}

class LoanCapitalPaymentsSupabaseDatasource
    implements LoanCapitalPaymentsRemoteDatasource {
  final SupabaseClient _client;
  const LoanCapitalPaymentsSupabaseDatasource(this._client);

  @override
  Future<List<LoanCapitalPaymentEntity>> getCapitalPayments() async {
    AppLogger.debug('getCapitalPayments called');
    final data = await _client
        .from('wallet_loan_capital_payments')
        .select()
        .isFilter('deletedAt', null)
        .order('paidAt');
    return (data as List)
        .map(
          (e) => LoanCapitalPaymentEntity.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<LoanCapitalPaymentEntity> createCapitalPayment({
    required String loanId,
    required double value,
    required DateTime paidAt,
  }) async {
    AppLogger.debug('createCapitalPayment called: $loanId');
    final data = await _client
        .from('wallet_loan_capital_payments')
        .insert({
          'userId': _client.auth.currentUser!.id,
          'loanId': loanId,
          'value': value,
          'paidAt': formatLoanDate(paidAt),
        })
        .select()
        .single();
    return LoanCapitalPaymentEntity.fromJson(data);
  }

  @override
  Future<void> deleteCapitalPayment({required String id}) async {
    AppLogger.debug('deleteCapitalPayment called: $id');
    final ok = await _client.rpc<bool>(
      'soft_delete_wallet_loan_capital_payment',
      params: {'p_id': id},
    );
    if (ok != true) {
      throw Exception(
        'soft_delete_wallet_loan_capital_payment: no row updated for $id',
      );
    }
  }
}
