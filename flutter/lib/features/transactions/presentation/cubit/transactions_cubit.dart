import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/credit_group_description.dart';
import '../../../../core/credit_ledger_grouping.dart';
import '../../../../core/deferred_credit_installment_schedule.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote_load_failure.dart';
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
import '../../domain/usecases/mark_credit_installments_paid_usecase.dart';
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
  final MarkCreditInstallmentsPaidUsecase _markCreditInstallmentsPaid;

  TransactionsCubit({
    required GetTransactionsUsecase getTransactions,
    required CreateTransactionUsecase createTransaction,
    required UpdateTransactionUsecase updateTransaction,
    required DeleteTransactionUsecase deleteTransaction,
    required CreateAccountTransferUsecase createAccountTransfer,
    required GetTransactionsByCreditGroupIdUsecase
    getTransactionsByCreditGroupId,
    required CreateWalletCreditUsecase createWalletCredit,
    required GetCardsUsecase getCards,
    required GetWalletCreditUsecase getWalletCredit,
    required UpdateWalletCreditUsecase updateWalletCredit,
    required MarkCreditInstallmentsPaidUsecase markCreditInstallmentsPaid,
  }) : _getTransactions = getTransactions,
       _createTransaction = createTransaction,
       _updateTransaction = updateTransaction,
       _deleteTransaction = deleteTransaction,
       _createAccountTransfer = createAccountTransfer,
       _getTransactionsByCreditGroupId = getTransactionsByCreditGroupId,
       _createWalletCredit = createWalletCredit,
       _getCards = getCards,
       _getWalletCredit = getWalletCredit,
       _updateWalletCredit = updateWalletCredit,
       _markCreditInstallmentsPaid = markCreditInstallmentsPaid,
       super(const TransactionsInitial());

  bool _transactionsOfflineFlag() => switch (state) {
    TransactionsLoaded(:final servedFromOfflineCache) => servedFromOfflineCache,
    TransactionsActionError(:final servedFromOfflineCache) =>
      servedFromOfflineCache,
    _ => false,
  };

  /// Last month that was requested via [loadForMonth] (normalized local day 1).
  DateTime? _loadedMonthStart;

  int _loadGeneration = 0;

  /// Loads rows for the local calendar month of [monthStartLocal] (year/month; day ignored).
  /// Discards responses from older requests if the user switches month quickly.
  Future<void> loadForMonth(
    DateTime monthStartLocal, {
    bool showLoading = true,
  }) async {
    final month = DateTime(monthStartLocal.year, monthStartLocal.month, 1);
    _loadedMonthStart = month;
    final gen = ++_loadGeneration;
    if (showLoading) emit(const TransactionsLoading());
    try {
      final bundle = await _getTransactions(month);
      if (gen != _loadGeneration) return;
      if (isClosed) return;
      final transactions = bundle.value;
      AppLogger.info(
        'transactions loaded for ${month.year}-${month.month}: ${transactions.length}',
      );
      emit(
        TransactionsLoaded(
          transactions,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      if (gen != _loadGeneration) return;
      if (isClosed) return;
      AppLogger.error('failed to load transactions', e, s);
      emit(TransactionsError(failure: classifyRemoteLoadError(e)));
    }
  }

  Future<void> _refetchCurrentMonthQuietly() async {
    final m = _loadedMonthStart;
    if (m == null) return;
    final prev = _currentTransactions();
    final snapshotMonth = DateTime(m.year, m.month, 1);
    try {
      final bundle = await _getTransactions(snapshotMonth);
      if (snapshotMonth != _loadedMonthStart) return;
      if (isClosed) return;
      emit(
        TransactionsLoaded(
          bundle.value,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      if (isClosed) return;
      AppLogger.error('failed to refetch transactions', e, s);
      emit(
        TransactionsActionError(
          prev,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
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
    final graceMonths = deferredGraceMonths.clamp(0, 1200);
    final useDeferred =
        deferredCredit && cardId != null && deferredTermMonths >= 2;

    try {
      if (useDeferred) {
        final parts = splitEqualAmountParts(value, deferredTermMonths);
        final anchor = transactedAt;
        final cards = (await _getCards()).value;
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
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
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
    final creditLedgerKey = (creditId != null && creditId.isNotEmpty)
        ? creditId
        : null;
    try {
      if (creditLedgerKey != null && creditLedgerKey.isNotEmpty) {
        final siblings = (await _getTransactionsByCreditGroupId(
          creditLedgerKey,
        )).value;
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
          final wc = (await _getWalletCredit(creditLedgerKey)).value;
          final ng = creditGraceMonths;
          final nt = creditTermMonths;
          final useReschedule =
              wc != null &&
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
            final cards = (await _getCards()).value;
            final cardIdx = cards.indexWhere((c) => c.id == cardId);
            if (cardIdx < 0) {
              throw StateError(
                'Credit reschedule requires the card (cut/pay days).',
              );
            }
            final card = cards[cardIdx];
            final schedule = scheduleDeferredCreditInstallmentsLocal(
              purchaseLocal: transactedAt.toLocal(),
              graceMonths: graceStored,
              termMonths: newTerm,
              cardCutDay: card.cutDay,
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
              transactedAt: transactedAt,
            );
            AppLogger.info(
              'credit group rescheduled ($creditLedgerKey): $newTerm rows',
            );
          } else {
            DateTime baselineLocal;
            if (wc != null) {
              baselineLocal = wc.transactedAt.toLocal();
            } else {
              var anchor = siblings.first;
              for (final e in siblings) {
                if (e.id == id) {
                  anchor = e;
                  break;
                }
              }
              baselineLocal = anchor.transactedAt.toLocal();
            }
            final delta = transactedAt.difference(baselineLocal);
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
            if (wc != null) {
              await _updateWalletCredit(
                id: creditLedgerKey,
                graceMonths: wc.graceMonths,
                termMonths: wc.termMonths,
                transactedAt: transactedAt,
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
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
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
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
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
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
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
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
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
        final group = (await _getTransactionsByCreditGroupId(creditLedgerKey))
            .value;
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
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
      return false;
    }
  }

  /// Pays off the credits [creditLedgerKeys] ahead of time with a card payment:
  /// one transfer from [accountId] to the card for everything still pending
  /// (installments due after today), and each of those installments is flagged
  /// with the id of the transfer's outflow leg. Flagged installments are left out
  /// of every list; deleting the transfer makes them owed again. Credits on
  /// different cards produce one transfer per card.
  ///
  /// Returns false when nothing is pending or when any step fails. If a transfer
  /// cannot be completed its legs are removed again so no money is recorded twice.
  Future<bool> payOffCredits({
    required List<String> creditLedgerKeys,
    required String accountId,
    required String description,
  }) async {
    final current = _currentTransactions();
    AppLogger.debug('paying off credits: $creditLedgerKeys');
    try {
      final pendingByCard = <String, List<TransactionEntity>>{};
      for (final key in creditLedgerKeys) {
        for (final t in (await _getTransactionsByCreditGroupId(key)).value) {
          final cardId = t.cardId;
          if (cardId == null ||
              t.paidByTransactionId != null ||
              installmentIsPaidThroughToday(t)) {
            continue;
          }
          pendingByCard.putIfAbsent(cardId, () => []).add(t);
        }
      }
      var paidAny = false;
      for (final entry in pendingByCard.entries) {
        final amount =
            (-entry.value.fold<double>(0, (a, t) => a + t.value) * 100)
                .round() /
            100;
        if (amount <= 0) continue;
        final now = DateTime.now();
        final group = const Uuid().v4();
        String? outflowId;
        String? inflowId;
        try {
          outflowId = (await _createTransaction(
            accountId: accountId,
            description: description,
            transactedAt: now,
            value: -amount,
            ignore: false,
            percentage: 100,
            transferGroupId: group,
          )).id;
          inflowId = (await _createTransaction(
            cardId: entry.key,
            description: description,
            transactedAt: now,
            value: amount,
            ignore: false,
            percentage: 100,
            transferGroupId: group,
          )).id;
          await _markCreditInstallmentsPaid(
            ids: [for (final t in entry.value) t.id],
            paidByTransactionId: outflowId,
          );
        } catch (_) {
          for (final id in [inflowId, outflowId]) {
            if (id == null) continue;
            try {
              await _deleteTransaction(id: id);
            } catch (e, s) {
              AppLogger.error('failed to undo credit payment leg', e, s);
            }
          }
          rethrow;
        }
        paidAny = true;
        AppLogger.info(
          'credits paid off: ${entry.value.length} installments by $outflowId',
        );
      }
      await _refetchCurrentMonthQuietly();
      return paidAny;
    } catch (e, s) {
      AppLogger.error('failed to pay off credits', e, s);
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
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
      emit(
        TransactionsActionError(
          current,
          servedFromOfflineCache: _transactionsOfflineFlag(),
        ),
      );
      return false;
    }
  }

  List<TransactionEntity> _currentTransactions() => switch (state) {
    TransactionsLoaded(:final transactions) => transactions,
    TransactionsActionError(:final transactions) => transactions,
    _ => [],
  };
}
