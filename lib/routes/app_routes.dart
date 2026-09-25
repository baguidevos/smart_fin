/// SamaFi — table des routes GetX.
///
/// Deux espaces de navigation :
///  * le **navigateur racine** (écrans plein écran : formulaires, détails,
///    sections « Plus ») ;
///  * le **navigateur imbriqué** (`ShellNav.id`) porté par la coque à onglets
///    (tableau de bord, comptes, historique, dettes, plus).
library;

abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const shell = '/shell';

  // ---- onglets (navigation imbriquée, id: ShellNav.id) --------------------
  static const tabHome = '/tabs/home';
  static const tabAccounts = '/tabs/accounts';
  static const tabHistory = '/tabs/history';
  static const tabDebts = '/tabs/debts';
  static const tabMore = '/tabs/more';

  // ---- formulaires de mouvements ------------------------------------------
  static const incomeForm = '/income';
  static const expenseForm = '/expense';
  static const transferForm = '/transfer';

  // ---- comptes --------------------------------------------------------------
  static const accountForm = '/account-form';
  static const accountDetail = '/account-detail';

  // ---- dettes ----------------------------------------------------------------
  static const debtForm = '/debt-form';
  static const debtDetail = '/debt-detail';
  static const repayForm = '/repay';

  // ---- sections « Plus » -------------------------------------------------------
  static const tontines = '/tontines';
  static const tontineForm = '/tontine-form';
  static const funds = '/funds';
  static const fundForm = '/fund-form';
  static const purchases = '/purchases';
  static const purchaseForm = '/purchase-form';
  static const settings = '/settings';
}

/// Identifiant du navigateur imbriqué de la coque (GetX nested navigation).
abstract final class ShellNav {
  static const int id = 1;

  /// Ordre des onglets = ordre de la barre de navigation.
  static const List<String> tabs = [
    Routes.tabHome,
    Routes.tabAccounts,
    Routes.tabHistory,
    Routes.tabDebts,
    Routes.tabMore,
  ];
}
