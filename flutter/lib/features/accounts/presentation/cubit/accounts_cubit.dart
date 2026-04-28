import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/usecases/get_accounts_usecase.dart';
import '../../domain/usecases/create_account_usecase.dart';
import '../../domain/usecases/update_account_usecase.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import 'accounts_state.dart';

class AccountsCubit extends Cubit<AccountsState> {
  final GetAccountsUsecase _getAccounts;
  final CreateAccountUsecase _createAccount;
  final UpdateAccountUsecase _updateAccount;
  final DeleteAccountUsecase _deleteAccount;

  AccountsCubit({
    required GetAccountsUsecase getAccounts,
    required CreateAccountUsecase createAccount,
    required UpdateAccountUsecase updateAccount,
    required DeleteAccountUsecase deleteAccount,
  })  : _getAccounts = getAccounts,
        _createAccount = createAccount,
        _updateAccount = updateAccount,
        _deleteAccount = deleteAccount,
        super(const AccountsInitial());

  Future<void> load() async {
    AppLogger.debug('loading accounts');
    emit(const AccountsLoading());
    try {
      final accounts = await _getAccounts();
      AppLogger.info('accounts loaded: ${accounts.length}');
      emit(AccountsLoaded(accounts));
    } catch (e, s) {
      AppLogger.error('failed to load accounts', e, s);
      emit(const AccountsError());
    }
  }

  Future<void> create({required String name, String? description}) async {
    final current = _currentAccounts();
    AppLogger.debug('creating account: $name');
    try {
      final account = await _createAccount(name: name, description: description);
      AppLogger.info('account created: ${account.id}');
      emit(AccountsLoaded([...current, account]));
    } catch (e, s) {
      AppLogger.error('failed to create account', e, s);
      emit(AccountsActionError(current));
    }
  }

  Future<void> update({required String id, required String name, String? description}) async {
    final current = _currentAccounts();
    AppLogger.debug('updating account: $id');
    try {
      final updated = await _updateAccount(id: id, name: name, description: description);
      AppLogger.info('account updated: ${updated.id}');
      emit(AccountsLoaded(current.map((a) => a.id == id ? updated : a).toList()));
    } catch (e, s) {
      AppLogger.error('failed to update account', e, s);
      emit(AccountsActionError(current));
    }
  }

  Future<void> delete({required String id}) async {
    final current = _currentAccounts();
    AppLogger.debug('deleting account: $id');
    try {
      await _deleteAccount(id: id);
      AppLogger.info('account deleted: $id');
      emit(AccountsLoaded(current.where((a) => a.id != id).toList()));
    } catch (e, s) {
      AppLogger.error('failed to delete account', e, s);
      emit(AccountsActionError(current));
    }
  }

  List<AccountEntity> _currentAccounts() => switch (state) {
    AccountsLoaded(:final accounts) => accounts,
    AccountsActionError(:final accounts) => accounts,
    _ => [],
  };
}
