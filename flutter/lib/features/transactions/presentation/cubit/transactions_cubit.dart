import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/credit_group_description.dart';
import '../../../../core/deferred_credit_installment_schedule.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/split_equal_amounts.dart';
import '../../../cards/domain/usecases/get_cards_usecase.dart';
import '../../../wallet_credits/domain/usecases/create_wallet_credit_usecase.dart';
import '../../../wallet_credits/domain/usecases/get_wallet_credit_usecase.dart';
import '../../../wallet_credits/domain/usecases/update_wallet_credit_usecase.dart';
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
  final CreateWalletCreditUsecase _createWalletCredit;
  final GetCardsUsecase _getCards;
  final GetWalletCreditUsecase _getWalletCredit;
  final UpdateWalletCreditUsecase _updateWalletCredit;

  TransactionsCubit({
    required GetTransactionsUsecase getTransactions,
    required CreateTransactionUsecase createTransaction,
    required UpdateTransactionUsecase updateTransaction,
    required DeleteTransactionUsecase deleteTransaction,
    required CreateAccountTransferUsecase createAccountTransfer,
    required GetTransactionsByCreditGroupIdUsecase getTransactionsByCreditGroupId,
    required CreateWalletCreditUsecase createWalletCredit,
    required GetCardsUsecase getCards,
    required GetWalletCreditUsecase getWalletCredit,
    required UpdateWalletCreditUsecase updateWalletCredit,
  })  : _getTransactions = getTransactions,
        _createTransaction = createTransaction,
        _updateTransaction = updateTransaction,
        _deleteTransaction = deleteTransaction,
        _createAccountTransfer = createAccountTransfer,
        _getTransactionsByCreditGroupId = getTransactionsByCreditGroupId,
        _createWalletCredit = createWalletCredit,
        _getCards = getCards,
        _getWalletCredit = getWalletCredit,
        _updateWalletCredit = updateWalletCredit,
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
        final parts = splitEqualAmountParts(value, deferredTermMonths);
        final anchor = transactedAt;
        final cards = await _getCards();
        final cardIndex = cards.indexWhere((c) => c.id == cardId);
        if (cardIndex < 0) {
          throw StateError(
            'Deferred credit requires the selected card (cut/pay days).',
          );
        }
        final card = cards[cardIndex];
        final schedule = scheduleDeferredCreditInstallmentsLocal(
          purchaseLocal: transactedAt.toLocal(),
          graceMonths: graceMonths,
          termMonths: deferredTermMonths,
          cardCutDay: card.cutDay,
          cardPayDay: card.payDay,
        );
        final header = await _createWalletCredit(
          transactedAt: anchor,
          graceMonths: graceMonths,
          termMonths: deferredTermMonths,
          description: description,
        );
        for (var i = 0; i < deferredTermMonths; i++) {
          final at = schedule[i];
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
            ignore: true,
            percentage: percentage,
            transferGroupId: transferGroupId,
            creditId: header.id,
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
    String? creditId,
    int? creditGraceMonths,
    int? creditTermMonths,
  }) async {
    final current = _currentTransactions();
    AppLogger.debug('updating transaction: $id');
    final creditLedgerKey =
        (creditId != null && creditId.isNotEmpty) ? creditId : null;
    try {
      if (creditLedgerKey != null && creditLedgerKey.isNotEmpty) {
        final siblings = await _getTransactionsByCreditGroupId(creditLedgerKey);
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
            creditId: creditId,
          );
        } else {
          siblings.sort((a, b) => a.transactedAt.compareTo(b.transactedAt));
          final wc = await _getWalletCredit(creditLedgerKey);
          final ng = creditGraceMonths;
          final nt = creditTermMonths;
          final useReschedule = wc != null &&
              cardId != null &&
              cardId.isNotEmpty &&
              ng != null &&
              nt != null &&
              nt >= 2 &&
              (ng != wc.graceMonths ||
                  nt != wc.termMonths ||
                  nt != siblings.length);

          if (useReschedule) {
            final graceStored = ng.clamp(0, 1200);
            final newTerm = nt;
            final cards = await _getCards();
            final cardIdx = cards.indexWhere((c) => c.id == cardId);
            if (cardIdx < 0) {
              throw StateError(
                'Credit reschedule requires the card (cut/pay days).',
              );
            }
            final card = cards[cardIdx];
            final schedule = scheduleDeferredCreditInstallmentsLocal(
              purchaseLocal: wc.transactedAt.toLocal(),
              graceMonths: graceStored,
              termMonths: newTerm,
              cardCutDay: card.cutDay,
              cardPayDay: card.payDay,
            );
            final parts = splitEqualAmountParts(value, newTerm);

            for (var i = 0; i < newTerm; i++) {
              if (i < siblings.length) {
                final s = siblings[i];
                await _updateTransaction(
                  id: s.id,
                  accountId: accountId,
                  cardId: cardId,
                  categoryId: categoryId,
                  tagId: tagId,
                  description: creditGroupPrefixedDescription(
                    oneBasedCurrent: i + 1,
                    total: newTerm,
                    userNote: description,
                  ),
                  transactedAt: schedule[i],
                  value: parts[i],
                  ignore: ignore,
                  percentage: percentage,
                  transferGroupId: s.transferGroupId,
                  creditId: creditLedgerKey,
                );
              } else {
                await _createTransaction(
                  accountId: accountId,
                  cardId: cardId,
                  categoryId: categoryId,
                  tagId: tagId,
                  description: creditGroupPrefixedDescription(
                    oneBasedCurrent: i + 1,
                    total: newTerm,
                    userNote: description,
                  ),
                  transactedAt: schedule[i],
                  value: parts[i],
                  ignore: ignore,
                  percentage: percentage,
                  transferGroupId: null,
                  creditId: creditLedgerKey,
                );
              }
            }
            for (var j = newTerm; j < siblings.length; j++) {
              await _deleteTransaction(id: siblings[j].id);
            }
            await _updateWalletCredit(
              id: creditLedgerKey,
              graceMonths: graceStored,
              termMonths: newTerm,
            );
            AppLogger.info(
              'credit group rescheduled ($creditLedgerKey): $newTerm rows',
            );
          } else {
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
                creditId: s.creditId,
              );
            }
            AppLogger.info(
              'credit group updated ($creditLedgerKey): ${siblings.length} rows',
            );
          }
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
          creditId: creditId,
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
        creditId: source.creditId,
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
        creditId: target.creditId,
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

  Future<bool> delete({required String id, String? creditLedgerKey}) async {
    final current = _currentTransactions();
    AppLogger.debug('deleting transaction: $id');
    try {
      final idsToDelete = <String>{};
      idsToDelete.add(id);
      if (creditLedgerKey != null && creditLedgerKey.isNotEmpty) {
        final group = await _getTransactionsByCreditGroupId(creditLedgerKey);
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
