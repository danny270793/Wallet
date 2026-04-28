// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Cartera';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get fieldRequired => 'Obligatorio';

  @override
  String get unexpectedError => 'Ocurrió un error inesperado';

  @override
  String get dashboard => 'Inicio';

  @override
  String get settings => 'Ajustes';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Predeterminado del sistema';

  @override
  String get settingsLanguageEnglish => 'Inglés';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get accounts => 'Cuentas';

  @override
  String get noAccounts => 'No hay cuentas aún';

  @override
  String get newAccount => 'Nueva cuenta';

  @override
  String get accountName => 'Nombre';

  @override
  String get accountDescription => 'Descripción';

  @override
  String get accountBalance => 'Saldo';

  @override
  String get listBalanceTotalLabel => 'Total';

  @override
  String get editAccount => 'Editar cuenta';

  @override
  String get accountSubmitCreate => 'Crear';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String confirmDeleteAccount(String name) {
    return '¿Seguro que quieres eliminar «$name»?';
  }

  @override
  String get cards => 'Tarjetas';

  @override
  String get noCards => 'No hay tarjetas aún';

  @override
  String get newCard => 'Nueva tarjeta';

  @override
  String get editCard => 'Editar tarjeta';

  @override
  String get deleteCard => 'Eliminar tarjeta';

  @override
  String confirmDeleteCard(String name) {
    return '¿Seguro que quieres eliminar «$name»?';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get categories => 'Categorías';

  @override
  String get noCategories => 'No hay categorías aún';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get editCategory => 'Editar categoría';

  @override
  String get deleteCategory => 'Eliminar categoría';

  @override
  String confirmDeleteCategory(String name) {
    return '¿Seguro que quieres eliminar «$name»?';
  }

  @override
  String get tags => 'Etiquetas';

  @override
  String get noTags => 'No hay etiquetas aún';

  @override
  String get newTag => 'Nueva etiqueta';

  @override
  String get editTag => 'Editar etiqueta';

  @override
  String get deleteTag => 'Eliminar etiqueta';

  @override
  String confirmDeleteTag(String name) {
    return '¿Seguro que quieres eliminar «$name»?';
  }

  @override
  String get transactions => 'Transacciones';

  @override
  String get transactionsSearchTooltip => 'Buscar transacciones';

  @override
  String get transactionsSearchHint => 'Buscar por descripción';

  @override
  String get transactionsSearchTypeQuery =>
      'Escribe texto para buscar en todas tus transacciones';

  @override
  String get transactionsSearchNoResults =>
      'No hay transacciones que coincidan';

  @override
  String get transactionsPickMonth => 'Elegir mes';

  @override
  String get transactionsPickPreviousYear => 'Año anterior';

  @override
  String get transactionsPickNextYear => 'Año siguiente';

  @override
  String get year => 'Año';

  @override
  String get month => 'Mes';

  @override
  String get noTransactions => 'No hay transacciones aún';

  @override
  String noTransactionsInMonth(String monthYear) {
    return 'No hay transacciones en $monthYear';
  }

  @override
  String get newTransaction => 'Nueva transacción';

  @override
  String get transactionsFabTransfer => 'Transferir';

  @override
  String get transferSheetTitle => 'Transferir entre cuentas';

  @override
  String get transferSourceAccount => 'Origen';

  @override
  String get transferTargetAccount => 'Destino';

  @override
  String get transferDateLabel => 'Fecha';

  @override
  String get transferTimeLabel => 'Hora';

  @override
  String get transferAccountsMustDiffer =>
      'El origen y el destino deben ser cuentas distintas';

  @override
  String get transferNeedTwoAccounts =>
      'Añade al menos dos cuentas para transferir dinero entre ellas';

  @override
  String get transferAccountSearch => 'Buscar por nombre';

  @override
  String get transferAccountSearchHint => 'Filtrar por nombre de cuenta';

  @override
  String get transferAccountSearchNoResults =>
      'Ninguna cuenta coincide con tu búsqueda';

  @override
  String get editTransferTitle => 'Editar transferencia';

  @override
  String get editTransaction => 'Editar transacción';

  @override
  String get deleteTransaction => 'Eliminar transacción';

  @override
  String get confirmDeleteTransaction =>
      '¿Seguro que quieres eliminar esta transacción?';

  @override
  String get deleteTransferPair => 'Eliminar transferencia';

  @override
  String get confirmDeleteTransferPair =>
      'Esto eliminará ambos apuntes de la transferencia del registro.';

  @override
  String get none => 'Ninguno';

  @override
  String get transactionDateTime => 'Cuándo';

  @override
  String get transactionAccount => 'Cuenta';

  @override
  String get transactionCard => 'Tarjeta';

  @override
  String get transactionCategory => 'Categoría';

  @override
  String get transactionTag => 'Etiqueta';

  @override
  String get transactionAmount => 'Importe';

  @override
  String get transactionPercentage => 'Porcentaje';

  @override
  String get transactionIgnore => 'Ignorar';

  @override
  String get transactionIgnoredBadge => 'Ignorado';

  @override
  String transactionAmountValue(String amount) {
    return '$amount';
  }

  @override
  String get transactionsTotalIncome => 'Ingresos';

  @override
  String get transactionsTotalOutcome => 'Gastos';

  @override
  String get transactionsTotalBalance => 'Saldo';

  @override
  String get transactionsTotalsExcludingIgnoredHint =>
      'Excluyendo transacciones ignoradas';
}
