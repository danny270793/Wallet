import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote_load_failure.dart';
import '../../../../core/sort_by_name.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/usecases/get_accounts_usecase.dart';
import '../../domain/usecases/create_account_usecase.dart';
import '../../domain/usecases/update_account_usecase.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../domain/usecases/adjust_account_balance_via_transaction_usecase.dart';
import 'accounts_state.dart';

class AccountsCubit extends Cubit<AccountsState> {
  final GetAccountsUsecase _getAccounts;
  final CreateAccountUsecase _createAccount;
  final UpdateAccountUsecase _updateAccount;
  final DeleteAccountUsecase _deleteAccount;
  final AdjustAccountBalanceViaTransactionUsecase _adjustBalanceViaTransaction;

  AccountsCubit({
    required GetAccountsUsecase getAccounts,
    required CreateAccountUsecase createAccount,
    required UpdateAccountUsecase updateAccount,
    required DeleteAccountUsecase deleteAccount,
    required AdjustAccountBalanceViaTransactionUsecase
    adjustBalanceViaTransaction,
  }) : _getAccounts = getAccounts,
       _createAccount = createAccount,
       _updateAccount = updateAccount,
       _deleteAccount = deleteAccount,
       _adjustBalanceViaTransaction = adjustBalanceViaTransaction,
       super(const AccountsInitial());

  bool _preserveOfflineCacheFlag() => switch (state) {
    AccountsLoaded(:final servedFromOfflineCache) => servedFromOfflineCache,
    AccountsActionError(:final servedFromOfflineCache) =>
      servedFromOfflineCache,
    _ => false,
  };

  Future<void> load({bool showLoading = true}) async {
    AppLogger.debug('loading accounts');
    if (showLoading) emit(const AccountsLoading());
    try {
      final bundle = await _getAccounts();
      final accounts = sortedByName(bundle.value, (a) => a.name);
      AppLogger.info('accounts loaded: ${accounts.length}');
      emit(
        AccountsLoaded(
          accounts,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to load accounts', e, s);
      emit(AccountsError(failure: classifyRemoteLoadError(e)));
    }
  }

  Future<void> create({required String name, String? description}) async {
    final current = _currentAccounts();
    AppLogger.debug('creating account: $name');
    try {
      await _createAccount(name: name, description: description);
      AppLogger.info('account created');
      final bundle = await _getAccounts();
      final accounts = sortedByName(bundle.value, (a) => a.name);
      emit(
        AccountsLoaded(
          accounts,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to create account', e, s);
      emit(
        AccountsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
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
    AppLogger.debug('updating account: $id');
    try {
      await _updateAccount(id: id, name: name, description: description);
      final delta = targetBalance - previousBalance;
      if (delta.abs() >= 1e-9) {
        await _adjustBalanceViaTransaction(accountId: id, delta: delta);
      }
      final bundle = await _getAccounts();
      final accounts = sortedByName(bundle.value, (a) => a.name);
      AppLogger.info('account updated: $id');
      emit(
        AccountsLoaded(
          accounts,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to update account', e, s);
      try {
        final bundle = await _getAccounts();
        final reloaded = sortedByName(bundle.value, (a) => a.name);
        emit(
          AccountsActionError(
            reloaded,
            servedFromOfflineCache: bundle.servedFromOfflineCache,
          ),
        );
      } catch (_) {
        emit(
          AccountsActionError(
            current,
            servedFromOfflineCache: _preserveOfflineCacheFlag(),
          ),
        );
      }
    }
  }

  Future<bool> delete({required String id}) async {
    final current = _currentAccounts();
    AppLogger.debug('deleting account: $id');
    try {
      await _deleteAccount(id: id);
      AppLogger.info('account deleted: $id');
      emit(
        AccountsLoaded(
          sortedByName(
            current.where((a) => a.id != id).toList(),
            (a) => a.name,
          ),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete account', e, s);
      emit(
        AccountsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return false;
    }
  }

  List<AccountEntity> _currentAccounts() => switch (state) {
    AccountsLoaded(:final accounts) => accounts,
    AccountsActionError(:final accounts) => accounts,
    _ => [],
  };
}
