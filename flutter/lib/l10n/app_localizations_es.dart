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
  String get monthlyDashboard => 'Panel mensual';

  @override
  String get monthlyDashboardConfigureTooltip =>
      'Opciones de gráficos y totales';

  @override
  String get monthlyDashboardOptionsSheetTitle => 'Opciones de vista';

  @override
  String get monthlyDashboardTransactionsListTitle => 'Transacciones';

  @override
  String get dashboardIncludeIgnoredInTotals =>
      'Incluir transacciones ignoradas';

  @override
  String get dashboardUseWeightedAmounts => 'Importes ponderados (%)';

  @override
  String get monthlyDashboardTagPieTitle => 'Gastos por etiqueta';

  @override
  String get monthlyDashboardCategoryPieTitle => 'Gastos por categoría';

  @override
  String get dashboardCategoryPieNoData =>
      'No hay gastos con categoría que mostrar este mes con el filtro actual.';

  @override
  String get dashboardTagPieNoData =>
      'No hay importes que mostrar este mes con el filtro actual.';

  @override
  String get dashboardTagPieFilterTags => 'Filtrar etiquetas';

  @override
  String get dashboardTagPieFilterDescription =>
      'Elige qué etiquetas incluir en el gráfico.';

  @override
  String get dashboardTagPieNeedOneTag => 'Selecciona al menos una etiqueta';

  @override
  String get dashboardCategoryPieFilterCategories => 'Filtrar categorías';

  @override
  String get dashboardCategoryPieFilterDescription =>
      'Elige qué categorías incluir en el gráfico.';

  @override
  String get dashboardCategoryPieNeedOneCategory =>
      'Selecciona al menos una categoría';

  @override
  String get dashboardPieDeselectAll => 'Deseleccionar todo';

  @override
  String get dashboardPieSelectAll => 'Seleccionar todo';

  @override
  String get yearlyDashboard => 'Panel anual';

  @override
  String get yearlyDashboardIncomeByMonthTitle => 'Ingresos por mes';

  @override
  String get yearlyDashboardOutcomeByMonthTitle => 'Gastos por mes';

  @override
  String get yearlyDashboardNetByMonthTitle => 'Saldo por mes';

  @override
  String get yearlyDashboardCumulativeByMonthTitle => 'Saldo acumulado por mes';

  @override
  String get navigationDashboards => 'Paneles';

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
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Predeterminado del sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get settingsAboutSection => 'Acerca de';

  @override
  String get settingsAboutApp => 'Acerca de';

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsPrivacyTagline => 'Cómo trata esta app tu información.';

  @override
  String get settingsPrivacyDataTitle => 'Qué guardas';

  @override
  String get settingsPrivacyDataBody =>
      'Wallet conserva los datos financieros que introduces—cuentas, tarjetas, movimientos, categorías, etiquetas y transferencias—para mostrar saldos e historial. La app no recopila datos que no hayas guardado con tu sesión iniciada.';

  @override
  String get settingsPrivacyInfraTitle => 'Dónde reside';

  @override
  String get settingsPrivacyInfraBody =>
      'Tus registros se almacenan en el backend que configures (por ejemplo Supabase) y el inicio de sesión que uses. La seguridad, copias de seguridad y quién puede acceder dependen de ese proveedor y de la configuración de tu proyecto. Usa contraseñas fuertes y protege las claves API.';

  @override
  String get settingsPrivacySharingTitle => 'Compartir y publicidad';

  @override
  String get settingsPrivacySharingBody =>
      'No vendemos tu información personal ni usamos tu libro de cuentas para mostrarte anuncios segmentados. Salvo el backend y el servicio de autenticación que elijas, la app no está pensada para enviar tus datos a intermediarios ni anunciantes.';

  @override
  String get settingsPrivacyNoticeTitle => 'Antes de publicar';

  @override
  String get settingsPrivacyNoticeBody =>
      'Este texto es un resumen orientativo, no asesoramiento legal. Antes de producción o de publicar en una tienda de apps, publica una política de privacidad acorde a tu jurisdicción, tu organización y cómo tratas los datos en la práctica.';

  @override
  String get settingsTermsOfUse => 'Términos de uso';

  @override
  String get settingsTermsTagline => 'Normas para usar esta app.';

  @override
  String get settingsTermsAcceptanceTitle => 'Aceptación';

  @override
  String get settingsTermsAcceptanceBody =>
      'Al acceder o usar Wallet aceptas estos términos. Si no estás de acuerdo, no uses la app.';

  @override
  String get settingsTermsDisclaimerTitle => 'No es asesoramiento profesional';

  @override
  String get settingsTermsDisclaimerBody =>
      'Wallet es una herramienta para organizar tus propios registros. Nada en la app ni en estos términos constituye asesoramiento financiero, legal, contable o fiscal. Usas la app y cualquier información en ella bajo tu propio riesgo al tomar decisiones.';

  @override
  String get settingsTermsLiabilityTitle => 'Limitación de responsabilidad';

  @override
  String get settingsTermsLiabilityBody =>
      'En la medida máxima permitida por la ley, los autores y colaboradores no serán responsables de daños indirectos, incidentales o consecuenciales, ni de pérdidas o decisiones que tomes basándote en la app. La app se ofrece «tal cual», sin garantías de ningún tipo.';

  @override
  String get settingsTermsResponsibilitiesTitle => 'Tus responsabilidades';

  @override
  String get settingsTermsResponsibilitiesBody =>
      'Eres responsable de proteger tu cuenta, credenciales, claves API y dispositivos. Debes cumplir las leyes y normas que te apliquen, incluidas las relativas a registros financieros e impuestos en tu jurisdicción.';

  @override
  String get settingsTermsNoticeTitle => 'Cambios y antes de publicar';

  @override
  String get settingsTermsNoticeBody =>
      'Estos términos pueden actualizarse ocasionalmente. Si sigues usando la app tras publicarse cambios, ello implica que aceptas los términos actualizados. Este texto es un resumen orientativo, no asesoramiento legal. Antes de producción o de publicar en una tienda de apps, publica términos acordes a tu jurisdicción, tu organización y tu servicio.';

  @override
  String get settingsAboutTagline =>
      'Tus finanzas personales en un solo lugar.';

  @override
  String get settingsAboutVersionLabel => 'Versión';

  @override
  String get settingsAboutFeaturesHeading => 'Qué puedes hacer';

  @override
  String get settingsAboutBulletAccounts =>
      'Conecta cuentas y tarjetas para reflejar tus saldos en la app.';

  @override
  String get settingsAboutBulletLedger =>
      'Registra movimientos, transferencias, categorías y etiquetas en un libro claro.';

  @override
  String get settingsAboutBulletMonth =>
      'Revisa cada mes y busca en tu historial cuando lo necesites.';

  @override
  String get settingsAboutDataHeading => 'Tus datos';

  @override
  String get settingsAboutDataBody =>
      'Lo que guardas se almacena en el backend que configures (por ejemplo Supabase) y queda asociado a tu sesión. Esta versión está pensada para uso personal.';

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
  String get assets => 'Activos';

  @override
  String get noAssets => 'No hay activos aún';

  @override
  String get assetSold => 'Vendido';

  @override
  String get newAsset => 'Nuevo activo';

  @override
  String get assetProvider => 'Proveedor';

  @override
  String get assetValue => 'Valor';

  @override
  String get assetPurchaseDate => 'Fecha de compra';

  @override
  String get assetEndDate => 'Fecha de fin';

  @override
  String get assetSoldAmountField => 'Importe de venta';

  @override
  String get assetInvalidNumber => 'Introduce un número válido';

  @override
  String get assetEndBeforePurchase =>
      'La fecha de fin debe ser igual o posterior a la de compra';

  @override
  String assetHeldDuration(String duration) {
    return 'Tenencia: $duration';
  }

  @override
  String assetValuePerApproximateMonth(String amount) {
    return '~$amount/mes (prom.)';
  }

  @override
  String assetSoldPerApproximateMonth(String amount) {
    return '~$amount/mes (venta prom.)';
  }

  @override
  String get editAsset => 'Editar activo';

  @override
  String get deleteAsset => 'Eliminar activo';

  @override
  String confirmDeleteAsset(String name) {
    return '¿Seguro que quieres eliminar «$name»?';
  }

  @override
  String get transactions => 'Transacciones';

  @override
  String get creditsNav => 'Créditos';

  @override
  String get creditsTitle => 'Créditos';

  @override
  String get creditsEmpty => 'Aún no tienes cuotas diferidas.';

  @override
  String get creditsUntitledGroup => 'Compra diferida';

  @override
  String creditsInstallmentsWithPending(int count, int pending) {
    return '$count cuotas - $pending pendientes';
  }

  @override
  String get creditsPendingTotalsLabel => 'Total pendiente';

  @override
  String get creditsPendingTotalsHint => 'Cuotas futuras · ponderado';

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
  String get yearlyPickYear => 'Elegir año';

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
  String get transferSheetTitle => 'Transferir';

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
      'El origen y el destino deben ser distintos';

  @override
  String get transferNeedTwoAccounts =>
      'Añade al menos dos cuentas o tarjetas para transferir entre ellas';

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
  String get confirmDeleteCreditGroupTransaction =>
      'Esta cuota forma parte de un pago diferido. Se eliminarán todas las cuotas de este grupo.';

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
  String get transactionPaymentMethod => 'Medio de pago';

  @override
  String get paymentMethodAddChoiceTitle => 'Añadir cuenta o tarjeta';

  @override
  String get transactionPaymentMethodSearchNoResults =>
      'Ningún medio de pago coincide con tu búsqueda';

  @override
  String get transactionDeferred => 'Diferido';

  @override
  String get transactionGraceMonths => 'Meses de gracia';

  @override
  String get transactionMesesPlazo => 'Meses plazo';

  @override
  String get transactionGraceMonthsInvalid =>
      'Los meses de gracia deben ser 0 o más';

  @override
  String get transactionTermMonthsInvalid => 'Indica al menos 2 meses de plazo';

  @override
  String get transactionCategory => 'Categoría';

  @override
  String get transactionTag => 'Etiqueta';

  @override
  String get transactionAmount => 'Importe';

  @override
  String get transactionAmountCreditGroupHint =>
      'El importe mostrado es el total del grupo repartido a partes iguales. Al guardar se actualizan todas las cuotas y las fechas se desplazan la misma cantidad.';

  @override
  String get transactionAmountInvalidNumber =>
      'Introduce un número válido (signo y decimales opcionales)';

  @override
  String get transactionAmountMustBeNonZero => 'El importe no puede ser cero';

  @override
  String get transferAmountMustBePositive =>
      'Introduce un importe mayor que cero';

  @override
  String get transactionPercentage => 'Porcentaje';

  @override
  String get transactionPercentageInvalidRange =>
      'Introduce un número entre 0 y 100';

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
  String get transactionsTotalsWeightedHint => 'Ponderado';

  @override
  String get transactionsTotalsWeightedExcludingIgnoredHint =>
      'Ponderado excluyendo ignoradas';

  @override
  String get transactionsTotalsNotWeightedHint => 'Sin ponderar';

  @override
  String get transactionsTotalsNotWeightedExcludingIgnoredHint =>
      'Sin ponderar excluyendo ignoradas';
}
