import '../features/cards/domain/entities/card_entity.dart';
import '../features/cards/domain/entities/card_type.dart';
import '../features/cards/domain/usecases/get_cards_usecase.dart';
import '../features/loans/domain/entities/loan_capital_payment_entity.dart';
import '../features/loans/domain/entities/loan_entity.dart';
import '../features/loans/domain/entities/loan_schedule.dart';
import '../features/loans/domain/usecases/get_loan_capital_payments_usecase.dart';
import '../features/loans/domain/usecases/get_loans_usecase.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/domain/usecases/list_transactions_having_credit_group_usecase.dart';
import 'credit_ledger_grouping.dart';
import 'di/injection.dart';
import 'logger/app_logger.dart';

/// Read-only monthly amount derived from a loan or a card, shown next to the
/// user's recurring movements and counted in their totals and estimates.
sealed class AutomaticRecurringMovement {
  const AutomaticRecurringMovement({required this.id, required this.name});

  /// Prefixed with the source kind so it never collides with a movement id.
  final String id;
  final String name;

  /// Signed monthly amount (negative = outcome).
  double get monthlyAmount;
}

/// Current installment of a loan that still has installments to pay.
class LoanRecurringMovement extends AutomaticRecurringMovement {
  LoanRecurringMovement(this.loan, {required this.installment})
    : super(id: 'loan:${loan.id}', name: loan.name);

  final LoanEntity loan;
  final double installment;

  @override
  double get monthlyAmount => -installment;
}

/// Interest a card's revolving balance generates in a month
/// (balance × nominal annual rate / 12).
class CardInterestRecurringMovement extends AutomaticRecurringMovement {
  CardInterestRecurringMovement(this.card, {required this.monthlyInterest})
    : super(id: 'card-interest:${card.id}', name: card.name);

  final CardEntity card;

  /// Positive amount.
  final double monthlyInterest;
  CardType? get type => card.type;

  @override
  double get monthlyAmount => -monthlyInterest;
}

/// Deferred installments of a card due this month.
class CardDeferredRecurringMovement extends AutomaticRecurringMovement {
  CardDeferredRecurringMovement(this.card, {required this.deferredThisMonth})
    : super(id: 'card-deferred:${card.id}', name: card.name);

  final CardEntity card;

  /// Negative, like the installments' values.
  final double deferredThisMonth;
  CardType? get type => card.type;

  @override
  double get monthlyAmount => deferredThisMonth;
}

/// Data behind the automatic rows, loaded once so any month can be computed
/// without reloading.
class AutomaticMovementsSource {
  const AutomaticMovementsSource({
    this.loans = const [],
    this.capitalPayments = const [],
    this.cards = const [],
    this.creditInstallments = const [],
  });

  final List<LoanEntity> loans;
  final List<LoanCapitalPaymentEntity> capitalPayments;
  final List<CardEntity> cards;
  final List<TransactionEntity> creditInstallments;

  /// Rows for the calendar month of [month]:
  /// - loans: the installment due that month, if any;
  /// - cards: that month's deferred installments, and the interest of the
  ///   revolving balance. Future spending is unknown, so the balance is
  ///   assumed to stay as it is today; it only grows by the deferred
  ///   installments posted between today and that month.
  List<AutomaticRecurringMovement> forMonth(DateTime month, {DateTime? today}) {
    final out = <AutomaticRecurringMovement>[];
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    for (final loan in loans) {
      for (final e in loanSchedule(loan, capitalPayments: capitalPayments)) {
        if (e is! LoanInstallmentEntry) continue;
        if (e.date.isBefore(monthStart) || e.date.isAfter(monthEnd)) continue;
        out.add(LoanRecurringMovement(loan, installment: e.payment));
      }
    }

    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final credits = creditTotalsByCard(creditInstallments);
    final deferred = <String, double>{};
    final postedBeforeMonth = <String, double>{};
    for (final t in creditInstallments) {
      final cardId = t.cardId;
      if (cardId == null) continue;
      final local = t.transactedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (!day.isBefore(monthStart) && !day.isAfter(monthEnd)) {
        deferred[cardId] = (deferred[cardId] ?? 0) + t.value;
      } else if (day.isAfter(todayDate) && day.isBefore(monthStart)) {
        postedBeforeMonth[cardId] = (postedBeforeMonth[cardId] ?? 0) + t.value;
      }
    }
    final isPast = monthEnd.isBefore(todayDate);
    for (final card in cards) {
      final revolving =
          cardPostedBalance(card.balance, credits[card.id]) +
          (isPast ? 0 : (postedBeforeMonth[card.id] ?? 0));
      final rate = card.nominalInterestRate ?? 0;
      final interest = revolving < 0 ? -revolving * rate / 100 / 12 : 0.0;
      final cardDeferred = deferred[card.id] ?? 0;
      if (interest >= 0.005) {
        out.add(CardInterestRecurringMovement(card, monthlyInterest: interest));
      }
      if (cardDeferred <= -0.005) {
        out.add(
          CardDeferredRecurringMovement(card, deferredThisMonth: cardDeferred),
        );
      }
    }
    return out;
  }
}

/// Loads everything [AutomaticMovementsSource.forMonth] needs. Each source is
/// optional: a failed load just leaves its rows out.
Future<AutomaticMovementsSource> loadAutomaticMovementsSource() async {
  var loans = const <LoanEntity>[];
  var capital = const <LoanCapitalPaymentEntity>[];
  var cards = const <CardEntity>[];
  var installments = const <TransactionEntity>[];
  try {
    loans = (await getIt<GetLoansUsecase>()()).value;
  } catch (e, s) {
    AppLogger.error('automatic movements: loans load failed', e, s);
  }
  try {
    capital = (await getIt<GetLoanCapitalPaymentsUsecase>()()).value;
  } catch (e, s) {
    AppLogger.error('automatic movements: capital payments load failed', e, s);
  }
  try {
    cards = (await getIt<GetCardsUsecase>()()).value;
  } catch (e, s) {
    AppLogger.error('automatic movements: cards load failed', e, s);
  }
  try {
    installments =
        (await getIt<ListTransactionsHavingCreditGroupUsecase>()()).value;
  } catch (e, s) {
    AppLogger.error('automatic movements: card credits load failed', e, s);
  }
  return AutomaticMovementsSource(
    loans: loans,
    capitalPayments: capital,
    cards: cards,
    creditInstallments: installments,
  );
}

/// Rows for the current month.
Future<List<AutomaticRecurringMovement>>
loadAutomaticRecurringMovements() async {
  final now = DateTime.now();
  return (await loadAutomaticMovementsSource()).forMonth(
    DateTime(now.year, now.month),
  );
}
