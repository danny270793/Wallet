import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calendar_months.dart';
import '../../../../core/credit_group_description.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/split_equal_amounts.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/create_transaction_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../domain/usecases/create_account_transfer_usecase.dart';
import '../../domain/usecases/get_transactions_by_credit_group_id_usecase.dart';
import 'transactions_state.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  final GetTransactionsUsecase _getTransactions;
  final CreateTransactionUsecase _createTransaction;
  final UpdateTransactionUsecase _updateTransaction;
  final DeleteTransactionUsecase _deleteTransaction;
  final CreateAccountTransferUsecase _createAccountTransfer;
  final GetTransactionsByCreditGroupIdUsecase _getTransactionsByCreditGroupId;

  TransactionsCubit({
    required GetTransactionsUsecase getTransactions,
    required CreateTransactionUsecase createTransaction,
    required UpdateTransactionUsecase updateTransaction,
    required DeleteTransactionUsecase deleteTransaction,
    required CreateAccountTransferUsecase createAccountTransfer,
    required GetTransactionsByCreditGroupIdUsecase getTransactionsByCreditGroupId,
  })  : _getTransactions = getTransactions,
        _createTransaction = createTransaction,
        _updateTransaction = updateTransaction,
        _deleteTransaction = deleteTransaction,
        _createAccountTransfer = createAccountTransfer,
        _getTransactionsByCreditGroupId = getTransactionsByCreditGroupId,
        super(const TransactionsInitial());

  /// Last month that was requested via [loadForMonth] (normalized local day 1).
  DateTime? _loadedMonthStart;

  int _loadGeneration = 0;

  /// Loads rows for the local calendar month of [monthStartLocal] (year/month; day ignored).
  /// Discards responses from older requests if the user switches month quickly.
  Future<void> loadForMonth(DateTime monthStartLocal, {bool showLoading = true}) async {
    final month = DateTime(monthStartLocal.year, monthStartLocal.month, 1);
    _loadedMonthStart = month;
    final gen = ++_loadGeneration;
    if (showLoading) emit(const TransactionsLoading());
    try {
      final transactions = await _getTransactions(month);
      if (gen != _loadGeneration) return;
      if (isClosed) return;
      AppLogger.info('transactions loaded for ${month.year}-${month.month}: ${transactions.length}');
      emit(TransactionsLoaded(transactions));
    } catch (e, s) {
      if (gen != _loadGeneration) return;
      if (isClosed) return;
      AppLogger.error('failed to load transactions', e, s);
      emit(const TransactionsError());
    }
  }

  Future<void> _refetchCurrentMonthQuietly() async {
    final m = _loadedMonthStart;
    if (m == null) return;
    final prev = _currentTransactions();
    final snapshotMonth = DateTime(m.year, m.month, 1);
    try {
      final list = await _getTransactions(snapshotMonth);
      if (snapshotMonth != _loadedMonthStart) return;
      if (isClosed) return;
      emit(TransactionsLoaded(list));
    } catch (e, s) {
      if (isClosed) return;
      AppLogger.error('failed to refetch transactions', e, s);
      emit(TransactionsActionError(prev));
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
    String? transferGroupId,
    bool deferredCredit = false,
    int deferredGraceMonths = 0,
    int deferredTermMonths = 1,
  }) async {
    final current = _currentTransactions();
    AppLogger.debug('creating transaction');
    final graceMonths =
        deferredGraceMonths.clamp(0, 1200);
    final useDeferred = deferredCredit &&
        cardId != null &&
        deferredTermMonths >= 2;

    try {
      if (useDeferred) {
        final uuid = const Uuid().v4();
        final parts = splitEqualAmountParts(value, deferredTermMonths);
        final anchor = transactedAt;
        for (var i = 0; i < deferredTermMonths; i++) {
          final at = addCalendarMonths(
            anchor,
            graceMonths + i,
          );
          await _createTransaction(
            accountId: accountId,
            cardId: cardId,
            categoryId: categoryId,
            tagId: tagId,
            description: creditGroupPrefixedDescription(
              oneBasedCurrent: i + 1,
              total: deferredTermMonths,
              userNote: description,
            ),
            transactedAt: at,
            value: parts[i],
            ignore: ignore,
            percentage: percentage,
            transferGroupId: transferGroupId,
            creditGroupId: uuid,
          );
        }
      } else {
        await _createTransaction(
          accountId: accountId,
          cardId: cardId,
          categoryId: categoryId,
          tagId: tagId,
          description: description,
          transactedAt: transactedAt,
          value: value,
          ignore: ignore,
          percentage: percentage,
          transferGroupId: transferGroupId,
        );
      }
      AppLogger.info('transaction created');
      await _refetchCurrentMonthQuietly();
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
    String? transferGroupId,
    String? creditGroupId,
  }) async {
    final current = _currentTransactions();
    AppLogger.debug('updating transaction: $id');
    try {
      if (creditGroupId != null && creditGroupId.isNotEmpty) {
        final siblings = await _getTransactionsByCreditGroupId(creditGroupId);
        if (siblings.isEmpty) {
          await _updateTransaction(
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
            transferGroupId: transferGroupId,
            creditGroupId: creditGroupId,
          );
        } else {
          siblings.sort((a, b) => a.transactedAt.compareTo(b.transactedAt));
          var anchor = siblings.first;
          for (final e in siblings) {
            if (e.id == id) {
              anchor = e;
              break;
            }
          }
          final delta = transactedAt.difference(anchor.transactedAt.toLocal());
          final parts = splitEqualAmountParts(value, siblings.length);
          for (var i = 0; i < siblings.length; i++) {
            final s = siblings[i];
            final shiftedLocal = s.transactedAt.toLocal().add(delta);
            await _updateTransaction(
              id: s.id,
              accountId: accountId,
              cardId: cardId,
              categoryId: categoryId,
              tagId: tagId,
              description: creditGroupPrefixedDescription(
                oneBasedCurrent: i + 1,
                total: siblings.length,
                userNote: description,
              ),
              transactedAt: shiftedLocal,
              value: parts[i],
              ignore: ignore,
              percentage: percentage,
              transferGroupId: s.transferGroupId,
              creditGroupId: creditGroupId,
            );
          }
          AppLogger.info('credit group updated ($creditGroupId): ${siblings.length} rows');
        }
      } else {
        await _updateTransaction(
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
          transferGroupId: transferGroupId,
          creditGroupId: creditGroupId,
        );
        AppLogger.info('transaction updated: $id');
      }
      await _refetchCurrentMonthQuietly();
    } catch (e, s) {
      AppLogger.error('failed to update transaction', e, s);
      emit(TransactionsActionError(current));
    }
  }

  /// Returns true if both transfer rows were created successfully.
  /// Each leg must set exactly one of accountId or cardId.
  Future<bool> transferBetweenPaymentMethods({
    required String? sourceAccountId,
    required String? sourceCardId,
    required String? targetAccountId,
    required String? targetCardId,
    required double amount,
    required DateTime transactedAt,
  }) async {
    final current = _currentTransactions();
    AppLogger.debug('payment method transfer');
    try {
      await _createAccountTransfer(
        sourceAccountId: sourceAccountId,
        sourceCardId: sourceCardId,
        targetAccountId: targetAccountId,
        targetCardId: targetCardId,
        amount: amount,
        transactedAt: transactedAt,
      );
      AppLogger.info('transfer created');
      await _refetchCurrentMonthQuietly();
      return true;
    } catch (e, s) {
      AppLogger.error('failed transfer', e, s);
      emit(TransactionsActionError(current));
      return false;
    }
  }

  /// Updates both legs of an existing transfer; refetches once.
  Future<bool> updateAccountTransfer({
    required TransactionEntity source,
    required TransactionEntity target,
    required String? sourceAccountId,
    required String? sourceCardId,
    required String? targetAccountId,
    required String? targetCardId,
    required double amount,
    required DateTime transactedAt,
    required bool ignore,
  }) async {
    final current = _currentTransactions();
    final gid = source.transferGroupId;
    if (gid == null || gid.isEmpty || gid != target.transferGroupId) {
      AppLogger.error('updateAccountTransfer: invalid or mismatched group id');
      emit(TransactionsActionError(current));
      return false;
    }
    AppLogger.debug('transfer update');
    try {
      await _updateTransaction(
        id: source.id,
        accountId: sourceAccountId,
        cardId: sourceCardId,
        categoryId: source.categoryId,
        tagId: source.tagId,
        description: source.description,
        transactedAt: transactedAt,
        value: -amount,
        ignore: ignore,
        percentage: source.percentage,
        transferGroupId: gid,
        creditGroupId: source.creditGroupId,
      );
      await _updateTransaction(
        id: target.id,
        accountId: targetAccountId,
        cardId: targetCardId,
        categoryId: target.categoryId,
        tagId: target.tagId,
        description: target.description,
        transactedAt: transactedAt,
        value: amount,
        ignore: ignore,
        percentage: target.percentage,
        transferGroupId: gid,
        creditGroupId: target.creditGroupId,
      );
      AppLogger.info('transfer updated');
      await _refetchCurrentMonthQuietly();
      return true;
    } catch (e, s) {
      AppLogger.error('failed transfer update', e, s);
      emit(TransactionsActionError(current));
      return false;
    }
  }

  Future<bool> delete({required String id, String? creditGroupId}) async {
    final current = _currentTransactions();
    AppLogger.debug('deleting transaction: $id');
    try {
      final idsToDelete = <String>{};
      idsToDelete.add(id);
      if (creditGroupId != null && creditGroupId.isNotEmpty) {
        final group = await _getTransactionsByCreditGroupId(creditGroupId);
        for (final t in group) {
          idsToDelete.add(t.id);
        }
      }
      for (final delId in idsToDelete) {
        await _deleteTransaction(id: delId);
      }
      AppLogger.info('transaction deleted: $idsToDelete');
      await _refetchCurrentMonthQuietly();
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete transaction', e, s);
      emit(TransactionsActionError(current));
      return false;
    }
  }

  /// Deletes several rows then refetches once (e.g. paired transfer legs).
  Future<bool> deleteMany(List<String> ids) async {
    final current = _currentTransactions();
    if (ids.isEmpty) return true;
    final unique = ids.toSet().toList();
    AppLogger.debug('deleting transactions: $unique');
    try {
      for (final id in unique) {
        await _deleteTransaction(id: id);
      }
      AppLogger.info('transactions deleted: $unique');
      await _refetchCurrentMonthQuietly();
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete transactions', e, s);
      emit(TransactionsActionError(current));
      return false;
    }
  }

  List<TransactionEntity> _currentTransactions() => switch (state) {
    TransactionsLoaded(:final transactions) => transactions,
    TransactionsActionError(:final transactions) => transactions,
    _ => [],
  };
}
