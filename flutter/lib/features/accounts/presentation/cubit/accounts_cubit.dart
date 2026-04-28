import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/usecases/get_accounts_usecase.dart';
import '../../domain/usecases/create_account_usecase.dart';
import '../../domain/usecases/update_account_usecase.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../../transactions/domain/usecases/get_account_balances_usecase.dart';
import '../../domain/usecases/adjust_account_balance_via_transaction_usecase.dart';
import 'accounts_state.dart';

class AccountsCubit extends Cubit<AccountsState> {
  final GetAccountsUsecase _getAccounts;
  final GetAccountBalancesUsecase _getAccountBalances;
  final CreateAccountUsecase _createAccount;
  final UpdateAccountUsecase _updateAccount;
  final DeleteAccountUsecase _deleteAccount;
  final AdjustAccountBalanceViaTransactionUsecase _adjustBalanceViaTransaction;

  AccountsCubit({
    required GetAccountsUsecase getAccounts,
    required GetAccountBalancesUsecase getAccountBalances,
    required CreateAccountUsecase createAccount,
    required UpdateAccountUsecase updateAccount,
    required DeleteAccountUsecase deleteAccount,
    required AdjustAccountBalanceViaTransactionUsecase adjustBalanceViaTransaction,
  })  : _getAccounts = getAccounts,
        _getAccountBalances = getAccountBalances,
        _createAccount = createAccount,
        _updateAccount = updateAccount,
        _deleteAccount = deleteAccount,
        _adjustBalanceViaTransaction = adjustBalanceViaTransaction,
        super(const AccountsInitial());

  Future<void> load() async {
    AppLogger.debug('loading accounts');
    emit(const AccountsLoading());
    try {
      final accounts = await _getAccounts();
      AppLogger.info('accounts loaded: ${accounts.length}');
      Map<String, double> balances = {};
      try {
        balances = await _getAccountBalances();
      } catch (e, s) {
        AppLogger.error('failed to load account balances', e, s);
      }
      emit(AccountsLoaded(accounts, balancesByAccountId: balances));
    } catch (e, s) {
      AppLogger.error('failed to load accounts', e, s);
      emit(const AccountsError());
    }
  }

  Future<void> create({required String name, String? description}) async {
    final current = _currentAccounts();
    final balances = _currentBalances();
    AppLogger.debug('creating account: $name');
    try {
      final account = await _createAccount(name: name, description: description);
      AppLogger.info('account created: ${account.id}');
      emit(AccountsLoaded(
        [...current, account],
        balancesByAccountId: {...balances, account.id: 0},
      ));
    } catch (e, s) {
      AppLogger.error('failed to create account', e, s);
      emit(AccountsActionError(current, balancesByAccountId: balances));
    }
  }

  Future<void> update({
    required String id,
    required String name,
    String? description,
    required double previousBalance,
    required double targetBalance,
  }) async {
    final current = _currentAccounts();
    final balances = _currentBalances();
    AppLogger.debug('updating account: $id');
    try {
      final updated = await _updateAccount(id: id, name: name, description: description);
      final delta = targetBalance - previousBalance;
      if (delta.abs() >= 1e-9) {
        await _adjustBalanceViaTransaction(accountId: id, delta: delta);
      }
      Map<String, double> newBalances = balances;
      try {
        newBalances = await _getAccountBalances();
      } catch (e, s) {
        AppLogger.error('failed to refresh account balances', e, s);
      }
      AppLogger.info('account updated: ${updated.id}');
      emit(AccountsLoaded(
        current.map((a) => a.id == id ? updated : a).toList(),
        balancesByAccountId: newBalances,
      ));
    } catch (e, s) {
      AppLogger.error('failed to update account', e, s);
      try {
        final reloaded = await _getAccounts();
        Map<String, double> b = {};
        try {
          b = await _getAccountBalances();
        } catch (_) {}
        emit(AccountsActionError(reloaded, balancesByAccountId: b));
      } catch (_) {
        emit(AccountsActionError(current, balancesByAccountId: balances));
      }
    }
  }

  Future<void> delete({required String id}) async {
    final current = _currentAccounts();
    final balances = Map<String, double>.from(_currentBalances())..remove(id);
    AppLogger.debug('deleting account: $id');
    try {
      await _deleteAccount(id: id);
      AppLogger.info('account deleted: $id');
      emit(AccountsLoaded(
        current.where((a) => a.id != id).toList(),
        balancesByAccountId: balances,
      ));
    } catch (e, s) {
      AppLogger.error('failed to delete account', e, s);
      emit(AccountsActionError(current, balancesByAccountId: _currentBalances()));
    }
  }

  List<AccountEntity> _currentAccounts() => switch (state) {
    AccountsLoaded(:final accounts) => accounts,
    AccountsActionError(:final accounts) => accounts,
    _ => [],
  };

  Map<String, double> _currentBalances() => switch (state) {
    AccountsLoaded(:final balancesByAccountId) => balancesByAccountId,
    AccountsActionError(:final balancesByAccountId) => balancesByAccountId,
    _ => const {},
  };
}
