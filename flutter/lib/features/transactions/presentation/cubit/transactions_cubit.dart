import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/create_transaction_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import 'transactions_state.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  final GetTransactionsUsecase _getTransactions;
  final CreateTransactionUsecase _createTransaction;
  final UpdateTransactionUsecase _updateTransaction;
  final DeleteTransactionUsecase _deleteTransaction;

  TransactionsCubit({
    required GetTransactionsUsecase getTransactions,
    required CreateTransactionUsecase createTransaction,
    required UpdateTransactionUsecase updateTransaction,
    required DeleteTransactionUsecase deleteTransaction,
  })  : _getTransactions = getTransactions,
        _createTransaction = createTransaction,
        _updateTransaction = updateTransaction,
        _deleteTransaction = deleteTransaction,
        super(const TransactionsInitial());

  Future<void> load() async {
    AppLogger.debug('loading transactions');
    emit(const TransactionsLoading());
    try {
      final transactions = await _getTransactions();
      AppLogger.info('transactions loaded: ${transactions.length}');
      emit(TransactionsLoaded(transactions));
    } catch (e, s) {
      AppLogger.error('failed to load transactions', e, s);
      emit(const TransactionsError());
    }
  }

  Future<void> create({
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
  }) async {
    final current = _currentTransactions();
    AppLogger.debug('creating transaction');
    try {
      final created = await _createTransaction(
        accountId: accountId,
        cardId: cardId,
        categoryId: categoryId,
        tagId: tagId,
        description: description,
        transactedAt: transactedAt,
        value: value,
        ignore: ignore,
        percentage: percentage,
      );
      AppLogger.info('transaction created: ${created.id}');
      final merged = [...current, created]..sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
      emit(TransactionsLoaded(merged));
    } catch (e, s) {
      AppLogger.error('failed to create transaction', e, s);
      emit(TransactionsActionError(current));
    }
  }

  Future<void> update({
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
  }) async {
    final current = _currentTransactions();
    AppLogger.debug('updating transaction: $id');
    try {
      final updated = await _updateTransaction(
        id: id,
        accountId: accountId,
        cardId: cardId,
        categoryId: categoryId,
        tagId: tagId,
        description: description,
        transactedAt: transactedAt,
        value: value,
        ignore: ignore,
        percentage: percentage,
      );
      AppLogger.info('transaction updated: ${updated.id}');
      final next = current.map((t) => t.id == id ? updated : t).toList()
        ..sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
      emit(TransactionsLoaded(next));
    } catch (e, s) {
      AppLogger.error('failed to update transaction', e, s);
      emit(TransactionsActionError(current));
    }
  }

  Future<void> delete({required String id}) async {
    final current = _currentTransactions();
    AppLogger.debug('deleting transaction: $id');
    try {
      await _deleteTransaction(id: id);
      AppLogger.info('transaction deleted: $id');
      emit(TransactionsLoaded(current.where((t) => t.id != id).toList()));
    } catch (e, s) {
      AppLogger.error('failed to delete transaction', e, s);
      emit(TransactionsActionError(current));
    }
  }

  List<TransactionEntity> _currentTransactions() => switch (state) {
    TransactionsLoaded(:final transactions) => transactions,
    TransactionsActionError(:final transactions) => transactions,
    _ => [],
  };
}
