/// SamaFi — déclaration des pages GetX (route → vue + binding).
///
/// Chaque page déclare son contrôleur via `BindingsBuilder` + `Get.lazyPut` :
/// le cycle de vie est piloté par le routeur (création à l'entrée, dispose à
/// la sortie), ce qui garantit l'absence de fuite mémoire entre onglets.
library;

import 'package:get/get.dart';

import '../modules/accounts/account_detail_view.dart';
import '../modules/accounts/account_form_view.dart';
import '../modules/accounts/accounts_view.dart';
import '../modules/debts/debt_detail_view.dart';
import '../modules/debts/debt_form_view.dart';
import '../modules/debts/debts_view.dart';
import '../modules/debts/repay_view.dart';
import '../modules/funds/fund_form_view.dart';
import '../modules/funds/funds_view.dart';
import '../modules/history/history_view.dart';
import '../modules/home/home_view.dart';
import '../modules/more/more_view.dart';
import '../modules/movements/expense_view.dart';
import '../modules/movements/income_view.dart';
import '../modules/movements/transfer_view.dart';
import '../modules/onboarding/onboarding_view.dart';
import '../modules/purchases/purchase_form_view.dart';
import '../modules/purchases/purchases_view.dart';
import '../modules/settings/settings_view.dart';
import '../modules/shell/shell_view.dart';
import '../modules/splash/splash_view.dart';
import '../modules/tontines/tontine_form_view.dart';
import '../modules/tontines/tontines_view.dart';
import '../routes/app_routes.dart';

abstract final class AppPages {
  static const String initial = Routes.splash;

  static final List<GetPage> pages = [
    // ---- démarrage ----------------------------------------------------------
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => SplashController())),
    ),
    GetPage(
      name: Routes.onboarding,
      page: () => const OnboardingView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => OnboardingController())),
    ),
    GetPage(
      name: Routes.shell,
      page: () => const ShellView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ShellController())),
    ),

    // ---- onglets (navigateur imbriqué ShellNav.id) ---------------------------
    GetPage(
      name: Routes.tabHome,
      page: () => const HomeView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => HomeController())),
    ),
    GetPage(
      name: Routes.tabAccounts,
      page: () => const AccountsView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => AccountsController())),
    ),
    GetPage(
      name: Routes.tabHistory,
      page: () => const HistoryView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => HistoryController())),
    ),
    GetPage(
      name: Routes.tabDebts,
      page: () => const DebtsView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => DebtsController())),
    ),
    GetPage(
      name: Routes.tabMore,
      page: () => const MoreView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => MoreController())),
    ),

    // ---- mouvements -----------------------------------------------------------
    GetPage(
      name: Routes.incomeForm,
      page: () => const IncomeView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => IncomeController())),
    ),
    GetPage(
      name: Routes.expenseForm,
      page: () => const ExpenseView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ExpenseController())),
    ),
    GetPage(
      name: Routes.transferForm,
      page: () => const TransferView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => TransferController())),
    ),

    // ---- comptes ---------------------------------------------------------------
    GetPage(
      name: Routes.accountForm,
      page: () => const AccountFormView(),
      binding:
          BindingsBuilder(() => Get.lazyPut(() => AccountFormController())),
    ),
    GetPage(
      name: Routes.accountDetail,
      page: () => const AccountDetailView(),
      binding:
          BindingsBuilder(() => Get.lazyPut(() => AccountDetailController())),
    ),

    // ---- dettes -----------------------------------------------------------------
    GetPage(
      name: Routes.debtForm,
      page: () => const DebtFormView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => DebtFormController())),
    ),
    GetPage(
      name: Routes.debtDetail,
      page: () => const DebtDetailView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => DebtDetailController())),
    ),
    GetPage(
      name: Routes.repayForm,
      page: () => const RepayView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => RepayController())),
    ),

    // ---- sections « Plus » ---------------------------------------------------------
    GetPage(
      name: Routes.tontines,
      page: () => const TontinesView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => TontinesController())),
    ),
    GetPage(
      name: Routes.tontineForm,
      page: () => const TontineFormView(),
      binding:
          BindingsBuilder(() => Get.lazyPut(() => TontineFormController())),
    ),
    GetPage(
      name: Routes.funds,
      page: () => const FundsView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => FundsController())),
    ),
    GetPage(
      name: Routes.fundForm,
      page: () => const FundFormView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => FundFormController())),
    ),
    GetPage(
      name: Routes.purchases,
      page: () => const PurchasesView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => PurchasesController())),
    ),
    GetPage(
      name: Routes.purchaseForm,
      page: () => const PurchaseFormView(),
      binding:
          BindingsBuilder(() => Get.lazyPut(() => PurchaseFormController())),
    ),
    GetPage(
      name: Routes.settings,
      page: () => const SettingsView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => SettingsController())),
    ),
  ];
}
