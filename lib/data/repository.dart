/// SamaFi — repository unique : état observable (Rx), règles métier du cahier
/// des charges, piste d'audit sur chaque opération et persistance GetStorage.
///
/// Invariants métier (identiques à la version web) :
///  * un encaissement est TOUJOURS ventilé (Σ allocations = montant total) ;
///  * un emprunt n'est pas un revenu (passif exigible, hors flux mensuels) ;
///  * un remboursement de dette n'est pas une dépense de consommation ;
///  * l'argent des tiers (fiducie, tontine) est étanche : mouvements tracés ;
///  * patrimoine net = actif disponible − créances internes − dettes restantes.
library;

import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../core/constants.dart';
import '../core/format.dart';
import 'models.dart';

/// Erreur métier : message français prêt à afficher (snackbar).
class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

Never _fail(String message) => throw AppException(message);

/// Extension pratique : affiche proprement une erreur en snackbar.
String errorMessage(Object e) =>
    e is AppException ? e.message : "Une erreur inattendue est survenue : $e";

class FinanceRepository extends GetxService {
  static const String storageName = 'samafi';

  final GetStorage _box = GetStorage(storageName);

  // ---- état observable -------------------------------------------------
  final accounts = <Account>[].obs;
  final transactions = <Transaction>[].obs;
  final debts = <Debt>[].obs;
  final repayments = <DebtRepayment>[].obs;
  final tontines = <Tontine>[].obs;
  final funds = <ThirdPartyFund>[].obs;
  final purchases = <Purchase>[].obs;

  final profileName = ''.obs;
  final onboarded = false.obs;
  final darkMode = true.obs;

  int _seq = 0;

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  // ---- cycle de vie ------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    profileName.value = _box.read('profileName') ?? '';
    onboarded.value = _box.read('onboarded') ?? false;
    darkMode.value = _box.read('darkMode') ?? true;
    accounts.value = _readList('accounts', Account.fromJson);
    transactions.value = _readList('transactions', Transaction.fromJson);
    debts.value = _readList('debts', Debt.fromJson);
    repayments.value = _readList('repayments', DebtRepayment.fromJson);
    tontines.value = _readList('tontines', Tontine.fromJson);
    funds.value = _readList('funds', ThirdPartyFund.fromJson);
    purchases.value = _readList('purchases', Purchase.fromJson);
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.read(key);
    if (raw is! String || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persiste tout l'état et notifie les widgets observateurs.
  void _commit() {
    _box.write('profileName', profileName.value);
    _box.write('onboarded', onboarded.value);
    _box.write('darkMode', darkMode.value);
    _box.write(
        'accounts', jsonEncode(accounts.map((a) => a.toJson()).toList()));
    _box.write('transactions',
        jsonEncode(transactions.map((t) => t.toJson()).toList()));
    _box.write('debts', jsonEncode(debts.map((d) => d.toJson()).toList()));
    _box.write('repayments',
        jsonEncode(repayments.map((r) => r.toJson()).toList()));
    _box.write('tontines', jsonEncode(tontines.map((t) => t.toJson()).toList()));
    _box.write('funds', jsonEncode(funds.map((f) => f.toJson()).toList()));
    _box.write('purchases',
        jsonEncode(purchases.map((p) => p.toJson()).toList()));
    accounts.refresh();
    transactions.refresh();
    debts.refresh();
    repayments.refresh();
    tontines.refresh();
    funds.refresh();
    purchases.refresh();
  }

  // ---- lectures ----------------------------------------------------------

  Account? accountById(String? id) =>
      id == null ? null : accounts.where((a) => a.id == id).firstOrNull;

  Debt? debtById(String? id) =>
      id == null ? null : debts.where((d) => d.id == id).firstOrNull;

  Purchase? purchaseById(String? id) =>
      id == null ? null : purchases.where((p) => p.id == id).firstOrNull;

  Tontine? tontineById(String? id) =>
      id == null ? null : tontines.where((t) => t.id == id).firstOrNull;

  ThirdPartyFund? fundById(String? id) =>
      id == null ? null : funds.where((f) => f.id == id).firstOrNull;

  Transaction? transactionById(String? id) =>
      id == null ? null : transactions.where((t) => t.id == id).firstOrNull;

  String? accountName(String? id) => accountById(id)?.name;

  /// Comptes non archivés.
  List<Account> get activeAccounts =>
      accounts.where((a) => !a.isArchived).toList();

  /// Comptes « personnels » : tout sauf fiducie et tontine (argent de tiers).
  List<Account> get personalAccounts => activeAccounts
      .where((a) =>
          a.role != AccountRole.fiduciaire &&
          a.role != AccountRole.tontine)
      .toList();

  /// Comptes utilisables dans les virements internes (argent personnel uniquement).
  List<Account> get transferableAccounts => personalAccounts;

  List<Transaction> recentTransactions(int n) {
    final sorted = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(n).toList();
  }

  List<DebtRepayment> repaymentsFor(String debtId) =>
      repayments.where((r) => r.debtId == debtId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Fenêtre calendaire des 30 derniers jours (comme la version web).
  DateTime get _since30d {
    final d = DateTime.now().subtract(const Duration(days: 30));
    return DateTime(d.year, d.month, d.day);
  }

  // ---- agrégats (tableau de bord) ---------------------------------------

  /// Σ soldes hors comptes fiduciaires (la tontine y figure : c'est mon argent
  /// en circulation, récupérable à mon tour).
  int get actifDisponible => accounts
      .where((a) => a.role != AccountRole.fiduciaire)
      .fold(0, (s, a) => s + a.balance);

  int get fiduciaryTotal => accounts
      .where((a) => a.role == AccountRole.fiduciaire)
      .fold(0, (s, a) => s + a.balance);

  /// Créances internes : argent de tiers détourné pour un usage personnel,
  /// non encore reversé.
  int get creancesTotal =>
      funds.fold(0, (s, f) => s + (f.creance > 0 ? f.creance : 0));

  int get dettesRemainingTotal {
    var total = 0;
    for (final stat in debtStats) {
      if (!stat.settled) total += stat.remaining;
    }
    return total;
  }

  int get dettesRepaidTotal =>
      repayments.fold(0, (s, r) => s + r.amount);

  int get activeDebtCount => debts
      .where((d) => d.status == DebtStatus.active)
      .length;

  /// Patrimoine net = actif disponible − créances internes − dettes restantes.
  int get patrimoineNet =>
      actifDisponible - creancesTotal - dettesRemainingTotal;

  int get passifsExigibles =>
      fiduciaryTotal + creancesTotal + dettesRemainingTotal;

  int get epargneTotal => accounts
      .where((a) =>
          a.role == AccountRole.savings || a.role == AccountRole.project)
      .fold(0, (s, a) => s + a.balance);

  /// Liquidités immédiates (caisses).
  int get portefeuille => accounts
      .where((a) => a.role == AccountRole.wallet)
      .fold(0, (s, a) => s + a.balance);

  /// Revenus / dépenses de consommation des 30 derniers jours (l'emprunt et
  /// son remboursement en sont exclus par construction).
  ({int income, int expense}) flux30j() {
    final since = _since30d;
    var income = 0;
    var expense = 0;
    for (final t in transactions) {
      if (t.date.isBefore(since)) continue;
      if (t.type == TxType.income) income += t.amount;
      if (t.type == TxType.expense) expense += t.amount;
    }
    return (income: income, expense: expense);
  }

  int get depenseAujourdHui {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return transactions
        .where((t) =>
            !t.date.isBefore(start) &&
            (t.type == TxType.expense || t.type == TxType.tpSpend))
        .fold(0, (s, t) => s + t.amount);
  }

  /// Jours restants du mois (aujourd'hui inclus).
  int get joursMoisRestants {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return (lastDay - now.day + 1).clamp(1, 31);
  }

  /// Jours restants jusqu'à dimanche inclus (lundi = premier jour).
  int get joursSemaineRestants => ((7 - DateTime.now().weekday) % 7) + 1;

  /// Budget journalier disponible : portefeuille réparti sur [jours] jours.
  int budgetJournalier(int jours) =>
      (portefeuille / (jours < 1 ? 1 : jours)).floor();

  /// Dépenses des 30 derniers jours groupées par catégorie.
  Map<String, int> expensesByCategory30j() {
    final since = _since30d;
    final map = <String, int>{};
    for (final t in transactions) {
      if (t.type != TxType.expense || t.date.isBefore(since)) continue;
      final key = t.category ?? 'Autre';
      map[key] = (map[key] ?? 0) + t.amount;
    }
    final sorted = Map.fromEntries(map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));
    return sorted;
  }

  /// Statistiques d'enveloppes (allocation nette vs consommation sur 30 jours).
  /// Règle d'or financière : les virements sortants réduisent l'allocation
  /// nette (réallocation budgétaire) au lieu d'être comptés comme une dépense,
  /// évitant le double comptage et garantissant la parité exacte avec le solde du compte.
  List<({Account account, int allocated, int consumed})> envelopeStats30j() {
    final since = _since30d;
    return activeAccounts
        .where((a) => a.role == AccountRole.envelope)
        .map((e) {
      var allocated = 0;
      var consumed = 0;
      for (final t in transactions) {
        if (t.date.isBefore(since)) continue;
        // Entrées sur l'enveloppe (ventilations de revenus, virements entrants)
        if (t.toAccountId == e.id && t.type != TxType.debtIn) {
          allocated += t.amount;
        }
        // Règle d'or : réallocations / sorties vers d'autres comptes personnels
        if (t.fromAccountId == e.id &&
            (t.type == TxType.transfer || t.type == TxType.contribution)) {
          allocated -= t.amount;
        }
        // Consommation directe réelle (dépenses effectives)
        if (t.type == TxType.expense && t.fromAccountId == e.id) {
          consumed += t.amount;
        }
      }
      final netAllocated = allocated > 0 ? allocated : 0;
      return (account: e, allocated: netAllocated, consumed: consumed);
    }).toList()
      ..sort((a, b) => b.consumed.compareTo(a.consumed));
  }

  /// Vues calculées des dettes (soldes, progression, remboursements).
  List<DebtStat> get debtStats {
    final sorted = [...debts]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.map((d) {
      final rs = repaymentsFor(d.id);
      final repaid = rs.fold(0, (s, r) => s + r.amount);
      final totalDue = d.totalDue;
      final remaining = totalDue - repaid > 0 ? totalDue - repaid : 0;
      final settled =
          d.status == DebtStatus.settled || remaining <= 0;
      final destinationAccountName = transactions
          .where((t) => t.debtId == d.id && t.type == TxType.debtIn)
          .map((t) => accountName(t.toAccountId))
          .firstWhere((n) => n != null, orElse: () => null);
      return DebtStat(
        debt: d,
        repaid: repaid,
        totalDue: totalDue,
        remaining: remaining,
        progress: totalDue > 0 ? (repaid / totalDue).clamp(0.0, 1.0) : 0.0,
        settled: settled,
        destinationAccountName: destinationAccountName,
        repayments: rs,
      );
    }).toList();
  }

  List<FundStat> get fundStats => funds
      .map((f) => FundStat(
            fund: f,
            balance: accountById(f.accountId)?.balance ?? 0,
            creance: f.creance,
            settled: f.status == FundStatus.settled,
          ))
      .toList();

  List<PurchaseStat> get purchaseStats => purchases.map((p) {
        final saved = accountById(p.accountId)?.balance ?? 0;
        final count = transactions
            .where((t) =>
                t.purchaseId == p.id && t.type == TxType.contribution)
            .length;
        return PurchaseStat(
          purchase: p,
          saved: saved,
          contributionsCount: count,
          progress: p.targetCost > 0
              ? (saved / p.targetCost).clamp(0.0, 1.0)
              : 0.0,
        );
      }).toList();

  // ---- gardes ------------------------------------------------------------

  void _guardPositive(int amount, String subject) {
    if (amount <= 0) _fail("$subject doit être supérieur à 0 FCFA.");
  }

  void _guardSufficient(Account account, int amount) {
    if (account.balance < amount) {
      _fail(
          "Solde insuffisant sur « ${account.name} » : solde ${fcfa(account.balance)}, montant demandé ${fcfa(amount)}.");
    }
  }

  void _guardPersonal(Account account, String subject) {
    if (account.role == AccountRole.fiduciaire ||
        account.role == AccountRole.tontine) {
      _fail(
          "$subject : les comptes fiduciaires et tontines détiennent l'argent de tiers — impossible de les utiliser pour une opération personnelle.");
    }
  }

  // ---- écriture des opérations (avec piste d'audit) ----------------------

  Transaction _addTx({
    required TxType type,
    required int amount,
    required String label,
    String? category,
    DateTime? date,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String? purchaseId,
    String? thirdPartyFundId,
    String? tontineId,
    String? debtId,
    String? auditTrail,
  }) {
    final tx = Transaction(
      id: _newId(),
      type: type,
      amount: amount,
      label: label,
      category: category,
      date: date ?? DateTime.now(),
      accountId: accountId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      purchaseId: purchaseId,
      thirdPartyFundId: thirdPartyFundId,
      tontineId: tontineId,
      debtId: debtId,
      auditTrail: auditTrail,
      createdAt: DateTime.now(),
    );
    transactions.add(tx);
    transactions
        .sort((a, b) => b.date.compareTo(a.date) == 0
            ? b.createdAt.compareTo(a.createdAt)
            : b.date.compareTo(a.date));
    return tx;
  }

  void _credit(Account account, int amount) {
    final i = accounts.indexWhere((a) => a.id == account.id);
    if (i >= 0) accounts[i] = accounts[i].copyWith(balance: accounts[i].balance + amount);
  }

  void _debit(Account account, int amount) {
    final i = accounts.indexWhere((a) => a.id == account.id);
    if (i >= 0) accounts[i] = accounts[i].copyWith(balance: accounts[i].balance - amount);
  }

  // -- comptes --------------------------------------------------------------

  Account addAccount({
    required String name,
    required AccountRole role,
    int monthlyBudget = 0,
    int initialBalance = 0,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) _fail("Le nom du compte est obligatoire.");
    if (monthlyBudget < 0) _fail("Le budget mensuel ne peut pas être négatif.");
    if (monthlyBudget > 0 && !role.isBudgetable) {
      _fail(
          "Seuls les comptes « charges fixes » et « enveloppes » peuvent porter un budget mensuel.");
    }
    _guardPositive(initialBalance == 0 ? 1 : initialBalance,
        "Le solde initial");
    final account = Account(
      id: _newId(),
      name: trimmed,
      role: role,
      balance: initialBalance,
      monthlyBudget: monthlyBudget,
      color: role.colorHex,
      sortOrder: accounts.length,
      createdAt: DateTime.now(),
    );
    accounts.add(account);
    if (initialBalance > 0) {
      _addTx(
        type: TxType.income,
        amount: initialBalance,
        label: "Solde initial — $trimmed",
        accountId: account.id,
        toAccountId: account.id,
        date: DateTime.now(),
        auditTrail:
            "Solde initial à la création du compte « $trimmed » (${fcfa(initialBalance)}).",
      );
    }
    _commit();
    return account;
  }

  void updateAccount({
    required String id,
    required String name,
    int? monthlyBudget,
  }) {
    final account = accountById(id);
    if (account == null) _fail("Compte introuvable.");
    final trimmed = name.trim();
    if (trimmed.isEmpty) _fail("Le nom du compte est obligatoire.");
    var budget = account.monthlyBudget;
    if (monthlyBudget != null) {
      if (monthlyBudget < 0) _fail("Le budget mensuel ne peut pas être négatif.");
      if (monthlyBudget > 0 && !account.role.isBudgetable) {
        _fail(
            "Seuls les comptes « charges fixes » et « enveloppes » peuvent porter un budget mensuel.");
      }
      budget = monthlyBudget;
    }
    final i = accounts.indexWhere((a) => a.id == id);
    accounts[i] = accounts[i]
        .copyWith(name: trimmed, monthlyBudget: budget);
    _commit();
  }

  void toggleArchive(String id) {
    final i = accounts.indexWhere((a) => a.id == id);
    if (i < 0) return;
    accounts[i] = accounts[i].copyWith(isArchived: !accounts[i].isArchived);
    _commit();
  }

  void deleteAccount(String id) {
    final account = accountById(id);
    if (account == null) return;
    if (account.balance != 0) {
      _fail(
          "Impossible de supprimer un compte au solde non nul (${fcfa(account.balance)}) — videz-le ou archivez-le.");
    }
    final used = transactions.any((t) =>
        t.accountId == id ||
        t.fromAccountId == id ||
        t.toAccountId == id);
    final linked = funds.any((f) => f.accountId == id) ||
        tontines.any((t) => t.accountId == id) ||
        purchases.any((p) => p.accountId == id);
    if (used || linked) {
      _fail(
          "Impossible de supprimer « ${account.name} » : ce compte est lié à des opérations. Archivez-le plutôt.");
    }
    accounts.removeWhere((a) => a.id == id);
    _commit();
  }

  // -- encaissement ventilé --------------------------------------------------

  /// Enregistre un encaissement réparti sur plusieurs comptes.
  /// Règle : la somme des allocations doit être EXACTEMENT le montant total.
  void addIncome({
    required int totalAmount,
    required String label,
    required List<Allocation> allocations,
    DateTime? date,
  }) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) _fail("Le libellé est obligatoire.");
    _guardPositive(totalAmount, "Le montant total encaissé");
    if (allocations.isEmpty) {
      _fail("Ventilez l'encaissement sur au moins un compte.");
    }
    for (final alloc in allocations) {
      final name = accountName(alloc.accountId) ?? alloc.accountId;
      _guardPositive(alloc.amount, "Le montant alloué à « $name »");
    }
    final sum = allocations.fold(0, (s, a) => s + a.amount);
    final diff = totalAmount - sum;
    if (diff != 0) {
      final detail = diff > 0
          ? "il reste ${fcfa(diff)} à ventiler"
          : "${fcfa(-diff)} alloués en trop";
      _fail(
          "Ventilation incomplète : la somme des allocations (${fcfa(sum)}) doit être égale au montant total encaissé (${fcfa(totalAmount)}) — $detail.");
    }
    for (final alloc in allocations) {
      final account = accountById(alloc.accountId)!;
      _addTx(
        type: TxType.income,
        amount: alloc.amount,
        label: trimmed,
        date: date,
        accountId: account.id,
        toAccountId: account.id,
        auditTrail:
            "Encaissement ventilé → ${account.name} (ventilation de « $trimmed » : ${fcfa(totalAmount)})",
      );
      _credit(account, alloc.amount);
    }
    _commit();
  }

  /// Met à jour le montant d'un encaissement enregistré.
  /// Réajuste le solde du compte bénéficiaire :
  /// - Si le montant augmente, le compte est crédité du supplément.
  /// - Si le montant diminue, la différence est retirée du compte (après vérification que le solde est suffisant).
  void updateIncomeAmount({
    required String transactionId,
    required int newAmount,
  }) {
    final tx = transactionById(transactionId);
    if (tx == null) _fail("Encaissement introuvable.");
    if (tx.type != TxType.income) {
      _fail("Seul un encaissement peut être modifié par cette opération.");
    }
    _guardPositive(newAmount, "Le montant de l'encaissement");

    final oldAmount = tx.amount;
    if (oldAmount == newAmount) return;

    final accountId = tx.toAccountId ?? tx.accountId;
    if (accountId == null) {
      _fail("Compte bénéficiaire introuvable pour cet encaissement.");
    }
    final account = accountById(accountId);
    if (account == null) _fail("Compte bénéficiaire introuvable.");

    final diff = newAmount - oldAmount;
    if (diff > 0) {
      // L'encaissement a augmenté : on crédite le compte du supplément
      _credit(account, diff);
    } else {
      // L'encaissement a diminué : on doit déduire l'excédent du compte
      final toDeduct = -diff;
      _guardSufficient(account, toDeduct);
      _debit(account, toDeduct);
    }

    final i = transactions.indexWhere((t) => t.id == transactionId);
    transactions[i] = transactions[i].copyWith(
      amount: newAmount,
      auditTrail:
          "Encaissement « ${tx.label} » modifié : montant passé de ${fcfa(oldAmount)} à ${fcfa(newAmount)} sur « ${account.name} » — solde actuel : ${fcfa(account.balance)}.",
    );
    _commit();
  }

  // -- dépense ---------------------------------------------------------------

  void addExpense({
    required int amount,
    required String label,
    required String accountId,
    String? category,
    DateTime? date,
  }) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) _fail("Le libellé est obligatoire.");
    _guardPositive(amount, "La dépense");
    final account = accountById(accountId);
    if (account == null) _fail("Compte introuvable.");
    if (account.role == AccountRole.fiduciaire) {
      _fail(
          "Les dépenses sur l'argent d'un tiers passent par la section Fonds tiers (dépense objet).");
    }
    if (account.role == AccountRole.tontine) {
      _fail("Les mouvements de tontine passent par la section Tontines.");
    }
    _guardSufficient(account, amount);
    _addTx(
      type: TxType.expense,
      amount: amount,
      label: trimmed,
      category: category,
      date: date,
      accountId: account.id,
      fromAccountId: account.id,
      auditTrail:
          "Dépense « $trimmed »${category != null ? " ($category)" : ""} payée depuis « ${account.name} » — solde après opération : ${fcfa(account.balance - amount)}.",
    );
    _debit(account, amount);
    _commit();
  }

  /// Met à jour le montant d'une dépense enregistrée.
  /// Réajuste le solde du compte payeur :
  /// - Si le montant augmente, le compte est débité du complément (après vérification du solde suffisant).
  /// - Si le montant diminue, le compte est recrédité de la différence.
  void updateExpenseAmount({
    required String transactionId,
    required int newAmount,
  }) {
    final tx = transactionById(transactionId);
    if (tx == null) _fail("Dépense introuvable.");
    if (tx.type != TxType.expense) {
      _fail("Seule une dépense peut être modifiée par cette opération.");
    }
    _guardPositive(newAmount, "Le montant de la dépense");

    final oldAmount = tx.amount;
    if (oldAmount == newAmount) return;

    final accountId = tx.fromAccountId ?? tx.accountId;
    if (accountId == null) _fail("Compte payeur introuvable pour cette dépense.");
    final account = accountById(accountId);
    if (account == null) _fail("Compte payeur introuvable.");

    final diff = newAmount - oldAmount;
    if (diff > 0) {
      // La dépense a augmenté : on débite le compte payeur du supplément
      _guardSufficient(account, diff);
      _debit(account, diff);
    } else {
      // La dépense a diminué : on recrédite le compte payeur
      _credit(account, -diff);
    }

    final i = transactions.indexWhere((t) => t.id == transactionId);
    transactions[i] = transactions[i].copyWith(
      amount: newAmount,
      auditTrail:
          "Dépense « ${tx.label} »${tx.category != null ? " (${tx.category})" : ""} modifiée : montant passé de ${fcfa(oldAmount)} à ${fcfa(newAmount)} sur « ${account.name} » — solde actuel : ${fcfa(account.balance)}.",
    );
    _commit();
  }

  // -- virement interne --------------------------------------------------------

  void transfer({
    required int amount,
    required String fromAccountId,
    required String toAccountId,
    String? label,
    DateTime? date,
  }) {
    _guardPositive(amount, "Le virement");
    final from = accountById(fromAccountId);
    final to = accountById(toAccountId);
    if (from == null || to == null) _fail("Compte introuvable.");
    if (from.id == to.id) {
      _fail("Les comptes source et destination doivent être différents.");
    }
    _guardPersonal(from, "Compte source");
    _guardPersonal(to, "Compte destination");
    _guardSufficient(from, amount);
    _addTx(
      type: TxType.transfer,
      amount: amount,
      label: label?.trim().isNotEmpty == true
          ? label!.trim()
          : "Virement ${from.name} → ${to.name}",
      date: date,
      accountId: from.id,
      fromAccountId: from.id,
      toAccountId: to.id,
      auditTrail:
          "Virement interne de ${fcfa(amount)} : « ${from.name} » → « ${to.name} ».",
    );
    _debit(from, amount);
    _credit(to, amount);
    _commit();
  }

  /// Met à jour le montant d'un virement interne enregistré.
  /// Réajuste les soldes des deux comptes :
  /// - Si le montant augmente, le compte source est débité du supplément (si solde suffisant) et la destination est créditée.
  /// - Si le montant diminue, le compte destination est débité de l'excédent (si solde suffisant) et la source est recréditée.
  void updateTransferAmount({
    required String transactionId,
    required int newAmount,
  }) {
    final tx = transactionById(transactionId);
    if (tx == null) _fail("Virement introuvable.");
    if (tx.type != TxType.transfer) {
      _fail("Seul un virement peut être modifié par cette opération.");
    }
    _guardPositive(newAmount, "Le montant du virement");

    final oldAmount = tx.amount;
    if (oldAmount == newAmount) return;

    final fromId = tx.fromAccountId ?? tx.accountId;
    final toId = tx.toAccountId;
    if (fromId == null || toId == null) {
      _fail("Comptes source ou destination introuvables pour ce virement.");
    }
    final from = accountById(fromId);
    final to = accountById(toId);
    if (from == null || to == null) {
      _fail("Compte source ou destination introuvable.");
    }

    final diff = newAmount - oldAmount;
    if (diff > 0) {
      // Le virement a augmenté : la source doit envoyer plus
      _guardSufficient(from, diff);
      _debit(from, diff);
      _credit(to, diff);
    } else {
      // Le virement a diminué : la destination doit rendre l'excédent à la source
      final toReturn = -diff;
      _guardSufficient(to, toReturn);
      _debit(to, toReturn);
      _credit(from, toReturn);
    }

    final i = transactions.indexWhere((t) => t.id == transactionId);
    transactions[i] = transactions[i].copyWith(
      amount: newAmount,
      auditTrail:
          "Virement « ${tx.label} » modifié : montant ajusté de ${fcfa(oldAmount)} à ${fcfa(newAmount)} (« ${from.name} » → « ${to.name} »).",
    );
    _commit();
  }

  /// Met à jour le montant d'une opération financière (dépense, encaissement ou virement).
  void updateTransactionAmount({
    required String transactionId,
    required int newAmount,
  }) {
    final tx = transactionById(transactionId);
    if (tx == null) _fail("Opération introuvable.");
    switch (tx.type) {
      case TxType.expense:
        updateExpenseAmount(transactionId: transactionId, newAmount: newAmount);
      case TxType.income:
        updateIncomeAmount(transactionId: transactionId, newAmount: newAmount);
      case TxType.transfer:
        updateTransferAmount(transactionId: transactionId, newAmount: newAmount);
      default:
        _fail(
            "La modification de montant n'est pas supportée pour ce type d'opération (${tx.type.label}).");
    }
  }

  // -- dettes explicites -------------------------------------------------------

  /// Emprunt : capital reçu d'un créancier. Ce n'est PAS un revenu : seul le
  /// passif exigible augmente (patrimoine net impacté, flux mensuels intacts).
  Debt addDebt({
    required String creditor,
    required String description,
    required int principal,
    int fees = 0,
    DateTime? dueDate,
    String? destinationAccountId,
    DateTime? date,
  }) {
    final c = creditor.trim();
    final d = description.trim();
    if (c.isEmpty) _fail("Le créancier est obligatoire.");
    if (d.isEmpty) _fail("Le motif de l'emprunt est obligatoire.");
    _guardPositive(principal, "Le capital emprunté");
    if (fees < 0) _fail("Les frais / intérêts ne peuvent pas être négatifs.");

    Account? destination;
    if (destinationAccountId != null && destinationAccountId.isNotEmpty) {
      destination = accountById(destinationAccountId);
      if (destination == null) _fail("Compte de destination introuvable.");
      _guardPersonal(destination, "Compte de destination");
    }

    final debt = Debt(
      id: _newId(),
      creditor: c,
      description: d,
      principal: principal,
      fees: fees,
      dueDate: dueDate,
      createdAt: date ?? DateTime.now(),
    );
    debts.add(debt);

    if (destination != null) {
      _addTx(
        type: TxType.debtIn,
        amount: principal,
        label: "Emprunt de $c",
        date: date,
        accountId: destination.id,
        toAccountId: destination.id,
        debtId: debt.id,
        auditTrail:
            "Emprunt enregistré — créancier : $c, motif : $d (capital ${fcfa(principal)}${fees > 0 ? " + frais ${fcfa(fees)}" : ""} ; total dû ${fcfa(debt.totalDue)}) versé sur « ${destination.name} ». Passif exigible, hors revenus.",
      );
      _credit(destination, principal);
    }
    _commit();
    return debt;
  }

  /// Remboursement partiel ou total : réduit le passif, n'est pas une dépense
  /// de consommation. La dette passe en « soldée » quand le reste tombe à 0.
  Debt repayDebt({
    required String debtId,
    required int amount,
    String? fromAccountId,
    String? note,
    DateTime? date,
  }) {
    _guardPositive(amount, "Le remboursement");
    final debt = debtById(debtId);
    if (debt == null) _fail("Dette introuvable.");

    final repaid = repaymentsFor(debt.id).fold(0, (s, r) => s + r.amount);
    final remaining = debt.totalDue - repaid;
    if (remaining <= 0) {
      _fail(
          "La dette envers ${debt.creditor} est déjà soldée (${fcfa(repaid)} remboursés sur ${fcfa(debt.totalDue)}).");
    }
    if (amount > remaining) {
      _fail(
          "Le remboursement (${fcfa(amount)}) dépasse le reste à payer (${fcfa(remaining)}) — ajustez le montant.");
    }

    Account? source;
    if (fromAccountId != null && fromAccountId.isNotEmpty) {
      source = accountById(fromAccountId);
      if (source == null) _fail("Compte source introuvable.");
      _guardPersonal(source, "Compte source");
      _guardSufficient(source, amount);
    }

    final at = date ?? DateTime.now();

    if (source != null) {
      _addTx(
        type: TxType.debtRepay,
        amount: amount,
        label: "Remboursement à ${debt.creditor}",
        date: at,
        accountId: source.id,
        fromAccountId: source.id,
        debtId: debt.id,
        auditTrail:
            "Remboursement d'emprunt — ${fcfa(amount)} versés à ${debt.creditor} depuis « ${source.name} »${note != null && note.trim().isNotEmpty ? " (${note.trim()})" : ""}. Reste à payer après opération : ${fcfa(remaining - amount)}.",
      );
      _debit(source, amount);
    }

    repayments.add(DebtRepayment(
      id: _newId(),
      debtId: debt.id,
      amount: amount,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      date: at,
      fromAccountId: source?.id,
    ));

    final newRemaining = remaining - amount;
    final i = debts.indexWhere((x) => x.id == debt.id);
    debts[i] = newRemaining <= 0
        ? debts[i].copyWith(status: DebtStatus.settled, settledAt: at)
        : debts[i].copyWith(status: DebtStatus.active, settledAt: null);
    _commit();
    return debts[i];
  }

  // -- fonds tiers (fiducie) ----------------------------------------------------

  ThirdPartyFund addFund({
    required String title,
    required String owner,
    required int initialAmount,
    required String purpose,
    DateTime? deadline,
    DateTime? date,
  }) {
    final t = title.trim();
    final o = owner.trim();
    final p = purpose.trim();
    if (t.isEmpty) _fail("Le titre du fonds est obligatoire.");
    if (o.isEmpty) _fail("Le propriétaire du fonds est obligatoire.");
    if (p.isEmpty) _fail("L'objet du fonds est obligatoire.");
    _guardPositive(initialAmount, "Le montant initial du fonds");

    final account = Account(
      id: _newId(),
      name: "Fiducie — $o · $t",
      role: AccountRole.fiduciaire,
      balance: initialAmount,
      color: '#c2410c',
      sortOrder: accounts.length,
      createdAt: DateTime.now(),
    );
    accounts.add(account);

    final fund = ThirdPartyFund(
      id: _newId(),
      title: t,
      owner: o,
      initialAmount: initialAmount,
      purpose: p,
      deadline: deadline,
      accountId: account.id,
      createdAt: DateTime.now(),
    );
    funds.add(fund);

    _addTx(
      type: TxType.tpIn,
      amount: initialAmount,
      label: "Fonds reçu de $o",
      date: date,
      accountId: account.id,
      toAccountId: account.id,
      thirdPartyFundId: fund.id,
      auditTrail:
          "Fonds tiers enregistré — propriétaire : $o, objet : $p (${fcfa(initialAmount)}).",
    );
    _commit();
    return fund;
  }

  /// Dépense fiduciaire réalisée DANS l'objet convenu.
  void spendFund({
    required String fundId,
    required int amount,
    required String label,
    DateTime? date,
  }) {
    _guardPositive(amount, "La dépense objet");
    if (label.trim().isEmpty) _fail("Le libellé de la dépense est obligatoire.");
    final fund = fundById(fundId);
    if (fund == null) _fail("Fonds introuvable.");
    if (fund.status == FundStatus.settled) {
      _fail("Ce fonds est clôturé — plus aucune opération possible.");
    }
    final account = accountById(fund.accountId)!;
    _guardSufficient(account, amount);

    _addTx(
      type: TxType.tpSpend,
      amount: amount,
      label: label.trim(),
      date: date,
      accountId: account.id,
      fromAccountId: account.id,
      thirdPartyFundId: fund.id,
      auditTrail:
          "Dépense objet — ${fcfa(amount)} dépensés pour « ${fund.purpose} » à la demande de ${fund.owner}. Solde fiduciaire restant : ${fcfa(account.balance - amount)}.",
    );
    _debit(account, amount);
    final i = funds.indexWhere((f) => f.id == fund.id);
    funds[i] = funds[i]
        .copyWith(spentOnPurpose: funds[i].spentOnPurpose + amount);
    _commit();
  }

  /// Détournement : une partie du fonds est utilisée pour un usage personnel.
  /// Constitue une créance interne (dette envers le propriétaire du fonds).
  void divertFund({
    required String fundId,
    required int amount,
    required String destinationAccountId,
    DateTime? date,
  }) {
    _guardPositive(amount, "Le montant détourné");
    final fund = fundById(fundId);
    if (fund == null) _fail("Fonds introuvable.");
    if (fund.status == FundStatus.settled) {
      _fail("Ce fonds est clôturé — plus aucune opération possible.");
    }
    final account = accountById(fund.accountId)!;
    _guardSufficient(account, amount);
    final destination = accountById(destinationAccountId);
    if (destination == null) _fail("Compte de destination introuvable.");
    _guardPersonal(destination, "Compte de destination");

    _addTx(
      type: TxType.tpDivert,
      amount: amount,
      label: "Détournement — ${fund.owner} → ${destination.name}",
      date: date,
      accountId: account.id,
      fromAccountId: account.id,
      toAccountId: destination.id,
      thirdPartyFundId: fund.id,
      auditTrail:
          "Détournement de fonds tiers — ${fcfa(amount)} prélevés sur le fonds de ${fund.owner} pour un usage personnel, versés sur « ${destination.name} ». Créance interne : ${fcfa(fund.creance + amount)}.",
    );
    _debit(account, amount);
    _credit(destination, amount);
    final i = funds.indexWhere((f) => f.id == fund.id);
    funds[i] =
        funds[i].copyWith(divertedAmount: funds[i].divertedAmount + amount);
    _commit();
  }

  /// Reversement : je rembourse ma créance interne sur le fonds.
  void reimburseFund({
    required String fundId,
    required int amount,
    required String fromAccountId,
    DateTime? date,
  }) {
    _guardPositive(amount, "Le reversement");
    final fund = fundById(fundId);
    if (fund == null) _fail("Fonds introuvable.");
    if (fund.status == FundStatus.settled) {
      _fail("Ce fonds est clôturé — plus aucune opération possible.");
    }
    if (amount > fund.creance) {
      _fail(
          "Le reversement (${fcfa(amount)}) dépasse la créance restante (${fcfa(fund.creance)}) — ajustez le montant.");
    }
    final source = accountById(fromAccountId);
    if (source == null) _fail("Compte source introuvable.");
    _guardPersonal(source, "Compte source");
    _guardSufficient(source, amount);
    final account = accountById(fund.accountId)!;

    _addTx(
      type: TxType.tpReimburse,
      amount: amount,
      label: "Reversement à ${fund.owner}",
      date: date,
      accountId: account.id,
      fromAccountId: source.id,
      toAccountId: account.id,
      thirdPartyFundId: fund.id,
      auditTrail:
          "Reversement de créance interne — ${fcfa(amount)} rendus au fonds de ${fund.owner} depuis « ${source.name} ». Créance restante : ${fcfa(fund.creance - amount)}.",
    );
    _debit(source, amount);
    _credit(account, amount);
    final i = funds.indexWhere((f) => f.id == fund.id);
    funds[i] = funds[i]
        .copyWith(reimbursedAmount: funds[i].reimbursedAmount + amount);
    _commit();
  }

  /// Clôture d'un fonds : solde ET créance doivent être à zéro.
  void settleFund(String fundId) {
    final fund = fundById(fundId);
    if (fund == null) _fail("Fonds introuvable.");
    final balance = accountById(fund.accountId)?.balance ?? 0;
    if (balance != 0) {
      _fail(
          "Le fonds doit être soldé avant clôture — il reste ${fcfa(balance)} sur le compte fiduciaire.");
    }
    if (fund.creance > 0) {
      _fail(
          "Une créance de ${fcfa(fund.creance)} reste envers ${fund.owner} — reversez-la avant de clôturer.");
    }
    final i = funds.indexWhere((f) => f.id == fundId);
    funds[i] = funds[i].copyWith(status: FundStatus.settled, closedAt: DateTime.now());
    _commit();
  }

  // -- tontines ------------------------------------------------------------------

  Tontine addTontine({
    required String name,
    required int contributionAmount,
    required TontineFrequency frequency,
    required List<({String name, bool isMe})> members,
  }) {
    final n = name.trim();
    if (n.isEmpty) _fail("Le nom de la tontine est obligatoire.");
    _guardPositive(contributionAmount, "Le montant de la cotisation");
    if (members.length < 2) {
      _fail("Une tontine requiert au moins deux membres.");
    }
    final meCount = members.where((m) => m.isMe).length;
    if (meCount != 1) {
      _fail(
          "La tontine doit comporter exactement un membre « Moi » (actuellement : $meCount).");
    }

    final account = Account(
      id: _newId(),
      name: "Tontine — $n",
      role: AccountRole.tontine,
      balance: 0,
      color: '#4d7c0f',
      sortOrder: accounts.length,
      createdAt: DateTime.now(),
    );
    accounts.add(account);

    final tontine = Tontine(
      id: _newId(),
      name: n,
      contributionAmount: contributionAmount,
      frequency: frequency,
      accountId: account.id,
      currentRound: 0,
      totalRounds: members.length,
      members: [
        for (var i = 0; i < members.length; i++)
          TontineMember(
            id: _newId(),
            tontineId: '',
            name: members[i].name.trim(),
            position: i + 1,
            isMe: members[i].isMe,
          ),
      ],
      createdAt: DateTime.now(),
    );
    // relie les membres à la tontine
    final withIds = tontine.members
        .map((m) => TontineMember(
              id: m.id,
              tontineId: tontine.id,
              name: m.name,
              position: m.position,
              isMe: m.isMe,
            ))
        .toList();
    tontines.add(tontine.copyWith(members: withIds));
    _commit();
    return tontines.last;
  }

  /// Cotisation : sortie depuis un compte personnel vers la cagnotte tontine.
  void contributeTontine({
    required String tontineId,
    required String fromAccountId,
    DateTime? date,
  }) {
    final tontine = tontineById(tontineId);
    if (tontine == null) _fail("Tontine introuvable.");
    if (tontine.status == FundStatus.settled) {
      _fail("Cette tontine est terminée.");
    }
    final source = accountById(fromAccountId);
    if (source == null) _fail("Compte source introuvable.");
    _guardPersonal(source, "Compte source");
    _guardSufficient(source, tontine.contributionAmount);
    final account = accountById(tontine.accountId)!;

    _addTx(
      type: TxType.tontineOut,
      amount: tontine.contributionAmount,
      label: "Cotisation — ${tontine.name}",
      date: date,
      accountId: source.id,
      fromAccountId: source.id,
      toAccountId: account.id,
      tontineId: tontine.id,
      auditTrail:
          "Cotisation de tontine — ${fcfa(tontine.contributionAmount)} versés à « ${tontine.name} » depuis « ${source.name} ». Encours : ${fcfa(account.balance + tontine.contributionAmount)}.",
    );
    _debit(source, tontine.contributionAmount);
    _credit(account, tontine.contributionAmount);
    _commit();
  }

  /// Attribue le tour suivant au membre correspondant.
  ///  * membre ≠ moi : ma cotisation du tour quitte la cagnotte ;
  ///  * moi : je reçois le pot complet (cotisation × membres) sur un compte
  ///    personnel et mon encours retombe à zéro.
  void attributeTontineRound({
    required String tontineId,
    String? destinationAccountId,
    DateTime? date,
  }) {
    final tontine = tontineById(tontineId);
    if (tontine == null) _fail("Tontine introuvable.");
    if (tontine.status == FundStatus.settled) {
      _fail("Cette tontine est terminée.");
    }
    if (tontine.currentRound >= tontine.totalRounds) {
      _fail("Tous les tours ont déjà été attribués.");
    }
    final round = tontine.currentRound + 1;
    final member =
        tontine.members.where((m) => m.position == round).firstOrNull;
    if (member == null) _fail("Membre du tour $round introuvable.");
    final account = accountById(tontine.accountId)!;
    final at = date ?? DateTime.now();
    final pot = tontine.contributionAmount * tontine.totalRounds;

    final updatedMembers = tontine.members
        .map((m) => m.id == member.id
            ? m.copyWith(hasReceived: true, receivedAt: at)
            : m)
        .toList();

    if (member.isMe) {
      final destination = destinationAccountId == null
          ? null
          : accountById(destinationAccountId);
      if (destination == null) {
        _fail("Choisissez le compte personnel qui recevra le pot.");
      }
      _guardPersonal(destination, "Compte de réception");
      _addTx(
        type: TxType.tontineIn,
        amount: pot,
        label: "Tour $round reçu — ${tontine.name}",
        date: at,
        accountId: destination.id,
        toAccountId: destination.id,
        tontineId: tontine.id,
        auditTrail:
            "Tour de tontine attribué — je reçois le pot complet (${fcfa(pot)}) de « ${tontine.name} » sur « ${destination.name} ». Mon encours retombe à zéro.",
      );
      // remet mon encours à zéro et crédite le pot
      final i = accounts.indexWhere((a) => a.id == account.id);
      accounts[i] =
          accounts[i].copyWith(balance: 0);
      _credit(destination, pot);
    } else {
      _guardSufficient(account, tontine.contributionAmount);
      _addTx(
        type: TxType.tontineOut,
        amount: tontine.contributionAmount,
        label: "Tour $round — ${member.name}",
        date: at,
        accountId: account.id,
        fromAccountId: account.id,
        tontineId: tontine.id,
        auditTrail:
            "Tour $round attribué à ${member.name} — ma cotisation du tour (${fcfa(tontine.contributionAmount)}) quitte la cagnotte. Encours restant : ${fcfa(account.balance - tontine.contributionAmount)}.",
      );
      _debit(account, tontine.contributionAmount);
    }

    final finished = round >= tontine.totalRounds;
    final i = tontines.indexWhere((t) => t.id == tontine.id);
    tontines[i] = tontines[i].copyWith(
      currentRound: round,
      members: updatedMembers,
      status: finished ? FundStatus.settled : null,
    );
    _commit();
  }

  // -- achats planifiés ------------------------------------------------------------

  Purchase addPurchase({
    required String title,
    required int targetCost,
    DateTime? deadline,
  }) {
    final t = title.trim();
    if (t.isEmpty) _fail("Le titre de l'achat est obligatoire.");
    _guardPositive(targetCost, "Le coût cible");

    final account = Account(
      id: _newId(),
      name: "Cagnotte — $t",
      role: AccountRole.project,
      balance: 0,
      color: '#7c3aed',
      sortOrder: accounts.length,
      createdAt: DateTime.now(),
    );
    accounts.add(account);
    final purchase = Purchase(
      id: _newId(),
      title: t,
      targetCost: targetCost,
      deadline: deadline,
      accountId: account.id,
      createdAt: DateTime.now(),
    );
    purchases.add(purchase);
    _commit();
    return purchase;
  }

  /// Met à jour un achat planifié (titre, coût cible, date d'échéance souhaitée).
  /// Seul un achat actif (en préparation) peut être modifié.
  /// Le nom de la cagnotte associée est automatiquement synchronisé si le titre change.
  void updatePurchase({
    required String id,
    required String title,
    required int targetCost,
    DateTime? deadline,
  }) {
    final purchase = purchaseById(id);
    if (purchase == null) _fail("Achat introuvable.");
    if (purchase.status != PurchaseStatus.active) {
      _fail("Seul un achat en préparation peut être modifié.");
    }
    final t = title.trim();
    if (t.isEmpty) _fail("Le titre de l'achat est obligatoire.");
    _guardPositive(targetCost, "Le coût cible");

    final i = purchases.indexWhere((p) => p.id == id);
    purchases[i] = purchases[i].copyWith(
      title: t,
      targetCost: targetCost,
      deadline: deadline,
      clearDeadline: deadline == null,
    );

    // Synchronisation du nom du compte cagnotte si le titre change
    final cagnotte = accountById(purchase.accountId);
    if (cagnotte != null && cagnotte.name != "Cagnotte — $t") {
      final accIndex = accounts.indexWhere((a) => a.id == cagnotte.id);
      if (accIndex >= 0) {
        accounts[accIndex] = accounts[accIndex].copyWith(name: "Cagnotte — $t");
      }
    }

    _commit();
  }

  /// Supprime ou annule un projet d'achat.
  /// Si la cagnotte contient de l'argent (> 0 FCFA), la suppression est bloquée
  /// pour forcer l'utilisateur à rediriger les fonds vers un compte personnel.
  /// Si des opérations passées existent (ex. redirection), le statut devient annulé
  /// pour préserver l'audit trail ; sinon le projet et sa cagnotte vide sont supprimés.
  void deletePurchase(String id) {
    final purchase = purchaseById(id);
    if (purchase == null) return;
    final cagnotte = accountById(purchase.accountId);
    if (cagnotte != null && cagnotte.balance > 0) {
      _fail(
          "Impossible de supprimer un achat dont la cagnotte contient encore des fonds (${fcfa(cagnotte.balance)}) — redirigez d'abord les fonds.");
    }
    final hasTx = transactions.any((t) =>
        t.purchaseId == id || (cagnotte != null && t.accountId == cagnotte.id));
    if (hasTx) {
      final i = purchases.indexWhere((p) => p.id == id);
      purchases[i] = purchases[i].copyWith(
        status: PurchaseStatus.cancelled,
        closedAt: DateTime.now(),
      );
    } else {
      purchases.removeWhere((p) => p.id == id);
      if (cagnotte != null) {
        accounts.removeWhere((a) => a.id == cagnotte.id);
      }
    }
    _commit();
  }

  /// Cotisation à la cagnotte d'un achat planifié.
  void contributePurchase({
    required String purchaseId,
    required String fromAccountId,
    required int amount,
    DateTime? date,
  }) {
    _guardPositive(amount, "La cotisation");
    final purchase = purchaseById(purchaseId);
    if (purchase == null) _fail("Achat introuvable.");
    if (purchase.status != PurchaseStatus.active) {
      _fail("Cet achat n'est plus en préparation.");
    }
    final source = accountById(fromAccountId);
    if (source == null) _fail("Compte source introuvable.");
    _guardPersonal(source, "Compte source");
    _guardSufficient(source, amount);
    final cagnotte = accountById(purchase.accountId)!;

    _addTx(
      type: TxType.contribution,
      amount: amount,
      label: "Cotisation — ${purchase.title}",
      date: date,
      accountId: source.id,
      fromAccountId: source.id,
      toAccountId: cagnotte.id,
      purchaseId: purchase.id,
      auditTrail:
          "Cotisation à la cagnotte « ${purchase.title} » — ${fcfa(amount)} depuis « ${source.name} ». Cagnotte : ${fcfa(cagnotte.balance + amount)} / ${fcfa(purchase.targetCost)}.",
    );
    _debit(source, amount);
    _credit(cagnotte, amount);
    _commit();
  }

  /// Achat finalisé : la cagnotte paie le coût cible.
  void completePurchase(String purchaseId, {DateTime? date}) {
    final purchase = purchaseById(purchaseId);
    if (purchase == null) _fail("Achat introuvable.");
    if (purchase.status != PurchaseStatus.active) {
      _fail("Cet achat n'est plus en préparation.");
    }
    final cagnotte = accountById(purchase.accountId)!;
    if (cagnotte.balance < purchase.targetCost) {
      _fail(
          "La cagnotte ne contient pas encore le coût cible (${fcfa(cagnotte.balance)} / ${fcfa(purchase.targetCost)}) — continuez à cotiser.");
    }
    final at = date ?? DateTime.now();

    _addTx(
      type: TxType.purchasePaid,
      amount: purchase.targetCost,
      label: "Achat payé — ${purchase.title}",
      date: at,
      accountId: cagnotte.id,
      fromAccountId: cagnotte.id,
      purchaseId: purchase.id,
      auditTrail:
          "Achat finalisé — ${fcfa(purchase.targetCost)} payés pour « ${purchase.title} » depuis la cagnotte. ${cagnotte.balance - purchase.targetCost > 0 ? "Excédent conservé dans la cagnotte : ${fcfa(cagnotte.balance - purchase.targetCost)}." : "Cagnotte épuisée."}",
    );
    _debit(cagnotte, purchase.targetCost);
    final i = purchases.indexWhere((p) => p.id == purchaseId);
    purchases[i] = purchases[i]
        .copyWith(status: PurchaseStatus.completed, closedAt: at);
    _commit();
  }

  /// Renoncement : le montant de la cagnotte est redirigé vers un autre compte
  /// (ex. l'épargne) — décision tracée, pas d'argent volatilisé.
  void redirectPurchase({
    required String purchaseId,
    required String destinationAccountId,
    DateTime? date,
  }) {
    final purchase = purchaseById(purchaseId);
    if (purchase == null) _fail("Achat introuvable.");
    if (purchase.status != PurchaseStatus.active) {
      _fail("Cet achat n'est plus en préparation.");
    }
    final cagnotte = accountById(purchase.accountId)!;
    if (cagnotte.balance <= 0) {
      _fail("La cagnotte est vide — rien à rediriger.");
    }
    final destination = accountById(destinationAccountId);
    if (destination == null) _fail("Compte de destination introuvable.");
    _guardPersonal(destination, "Compte destination");
    final at = date ?? DateTime.now();
    final amount = cagnotte.balance;

    _addTx(
      type: TxType.redirection,
      amount: amount,
      label: "Redirection — ${purchase.title}",
      date: at,
      accountId: cagnotte.id,
      fromAccountId: cagnotte.id,
      toAccountId: destination.id,
      purchaseId: purchase.id,
      auditTrail:
          "Renoncement à l'achat « ${purchase.title} » — ${fcfa(amount)} de la cagnotte redirigés vers « ${destination.name} » (décision assumée, argent préservé).",
    );
    _debit(cagnotte, amount);
    _credit(destination, amount);
    final i = purchases.indexWhere((p) => p.id == purchaseId);
    purchases[i] = purchases[i]
        .copyWith(status: PurchaseStatus.redirected, closedAt: at);
    _commit();
  }

  // -- profil & données -------------------------------------------------------------

  void completeOnboarding({required String name}) {
    final n = name.trim();
    if (n.isEmpty) _fail("Votre prénom est obligatoire.");
    profileName.value = n;
    if (accounts.isEmpty) {
      addAccount(name: 'Caisse Principale', role: AccountRole.wallet);
      addAccount(name: 'Charges Fixes', role: AccountRole.budget);
      addAccount(name: 'Ravitaillement', role: AccountRole.envelope);
      addAccount(name: 'Loisirs', role: AccountRole.envelope);
      addAccount(name: 'Imprévus', role: AccountRole.envelope);
      addAccount(name: 'Économies', role: AccountRole.savings);
    }
    onboarded.value = true;
    _commit();
  }

  void renameProfile(String name) {
    final n = name.trim();
    if (n.isEmpty) _fail("Le prénom ne peut pas être vide.");
    profileName.value = n;
    _commit();
  }

  void setDarkMode(bool dark) {
    darkMode.value = dark;
    _box.write('darkMode', dark);
  }

  /// Supprime toutes les données (retour à l'écran d'accueil).
  void resetAll() {
    accounts.clear();
    transactions.clear();
    debts.clear();
    repayments.clear();
    tontines.clear();
    funds.clear();
    purchases.clear();
    profileName.value = '';
    onboarded.value = false;
    _commit();
  }

  /// Export CSV de l'historique (séparateur `;`, convention française).
  String exportTransactionsCsv() {
    final rows = <String>[
      'Date;Type;Libellé;Catégorie;Montant (FCFA);Compte;Compte destination;Traçabilité'
    ];
    final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
    String esc(String? s) => (s ?? '').replaceAll(';', ',');
    for (final t in sorted) {
      rows.add([
        dateField(t.date),
        t.type.label,
        esc(t.label),
        esc(t.category),
        t.amount.toString(),
        esc(accountName(t.fromAccountId ?? t.accountId)),
        esc(accountName(t.toAccountId)),
        esc(t.auditTrail),
      ].join(';'));
    }
    return rows.join('\n');
  }

  /// Génère une sauvegarde complète de toutes les données au format JSON (version 1.1.1).
  String exportBackupJson() {
    final payload = {
      'version': kAppVersion,
      'appName': 'SmartFin',
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {
        'profileName': profileName.value,
        'onboarded': onboarded.value,
        'darkMode': darkMode.value,
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'debts': debts.map((d) => d.toJson()).toList(),
        'repayments': repayments.map((r) => r.toJson()).toList(),
        'tontines': tontines.map((t) => t.toJson()).toList(),
        'funds': funds.map((f) => f.toJson()).toList(),
        'purchases': purchases.map((p) => p.toJson()).toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Restaure une sauvegarde complète (version 1.1.0 ou versions compatibles).
  ///
  /// Prend en charge les formats imbriqués sous `data` ou à plat,
  /// les listes sérialisées ou brutes, et persiste immédiatement l'état.
  ({int accountsCount, int transactionsCount, int debtsCount, String profileName})
      importBackupJson(String jsonString) {
    var cleaned = jsonString.trim();
    if (cleaned.startsWith('\uFEFF')) {
      cleaned = cleaned.substring(1).trim();
    }
    if (cleaned.isEmpty) {
      throw const FormatException('Le fichier de sauvegarde est vide.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (e) {
      throw FormatException('Fichier JSON invalide : $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'Structure de sauvegarde invalide (objet JSON attendu).');
    }

    // Extraction tolérante : soit sous "data", soit directement à la racine
    final Map<String, dynamic> dataMap = (decoded['data'] is Map<String, dynamic>)
        ? decoded['data'] as Map<String, dynamic>
        : decoded;

    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final val = dataMap[key];
      if (val == null) return [];
      if (val is List) {
        return val
            .whereType<Map<String, dynamic>>()
            .map((item) => fromJson(item))
            .toList();
      }
      if (val is String && val.isNotEmpty) {
        try {
          final subList = jsonDecode(val);
          if (subList is List) {
            return subList
                .whereType<Map<String, dynamic>>()
                .map((item) => fromJson(item))
                .toList();
          }
        } catch (_) {}
      }
      return [];
    }

    final newAccounts = parseList('accounts', Account.fromJson);
    final newTransactions = parseList('transactions', Transaction.fromJson);
    final newDebts = parseList('debts', Debt.fromJson);
    final newRepayments = parseList('repayments', DebtRepayment.fromJson);
    final newTontines = parseList('tontines', Tontine.fromJson);
    final newFunds = parseList('funds', ThirdPartyFund.fromJson);
    final newPurchases = parseList('purchases', Purchase.fromJson);

    final rawName = dataMap['profileName'] as String?;
    final newProfileName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : (profileName.value.isNotEmpty ? profileName.value : 'Utilisateur SmartFin');
    final newDarkMode = dataMap['darkMode'] as bool? ?? true;

    profileName.value = newProfileName;
    onboarded.value = true;
    darkMode.value = newDarkMode;
    accounts.value = newAccounts;
    transactions.value = newTransactions;
    debts.value = newDebts;
    repayments.value = newRepayments;
    tontines.value = newTontines;
    funds.value = newFunds;
    purchases.value = newPurchases;

    _commit();

    return (
      accountsCount: newAccounts.length,
      transactionsCount: newTransactions.length,
      debtsCount: newDebts.length,
      profileName: newProfileName,
    );
  }

  // -- données de démonstration ------------------------------------------------------

  /// Rejoue un mois type : salaires ventilés, dépenses catégorisées, achat
  /// planifié, fonds tiers avec détournement partiellement reversé, tontine
  /// de 8 membres et emprunt en cours de remboursement.
  void seedDemo() {
    resetAll();
    profileName.value = 'Awa Diop';
    onboarded.value = true;

    final caisse = addAccount(name: 'Caisse Principale', role: AccountRole.wallet);
    final charges =
        addAccount(name: 'Charges Fixes', role: AccountRole.budget, monthlyBudget: 60000);
    final courses =
        addAccount(name: 'Ravitaillement', role: AccountRole.envelope, monthlyBudget: 80000);
    final loisirs =
        addAccount(name: 'Loisirs', role: AccountRole.envelope, monthlyBudget: 25000);
    final imprev =
        addAccount(name: 'Imprévus', role: AccountRole.envelope, monthlyBudget: 15000);
    final epargne = addAccount(name: 'Économies', role: AccountRole.savings);

    // -- salaires ventilés (2 rentrées)
    for (final (i, d) in [daysAgo(28), daysAgo(14)].indexed) {
      addIncome(
        totalAmount: 250000,
        label: i == 0 ? 'Salaire — Mission Mbacké' : 'Salaire — Suite mission',
        date: d,
        allocations: [
          Allocation(accountId: caisse.id, amount: 60000),
          Allocation(accountId: charges.id, amount: 60000),
          Allocation(accountId: courses.id, amount: 70000),
          Allocation(accountId: loisirs.id, amount: 25000),
          Allocation(accountId: imprev.id, amount: 15000),
          Allocation(accountId: epargne.id, amount: 20000),
        ],
      );
    }
    addIncome(
      totalAmount: 60000,
      label: 'Prime de transport',
      date: daysAgo(10),
      allocations: [
        Allocation(accountId: caisse.id, amount: 40000),
        Allocation(accountId: epargne.id, amount: 20000),
      ],
    );

    // -- dépenses catégorisées
    addExpense(amount: 18000, label: 'Marché Sandaga', accountId: courses.id,
        category: 'Alimentation', date: daysAgo(27));
    addExpense(amount: 4500, label: 'Taxi — Plateau', accountId: caisse.id,
        category: 'Transport', date: daysAgo(25));
    addExpense(amount: 25000, label: 'Loyer de bande passante', accountId: charges.id,
        category: 'Factures', date: daysAgo(24));
    addExpense(amount: 12000, label: 'Pharmacie familiale', accountId: imprev.id,
        category: 'Santé', date: daysAgo(22));
    addExpense(amount: 9000, label: 'Cinéma + restaurant', accountId: loisirs.id,
        category: 'Loisirs', date: daysAgo(20));
    addExpense(amount: 15000, label: 'Inscription atelier couture', accountId: loisirs.id,
        category: 'Éducation', date: daysAgo(18));
    addExpense(amount: 16000, label: 'Courses de la semaine', accountId: courses.id,
        category: 'Alimentation', date: daysAgo(15));
    addExpense(amount: 7500, label: 'Pagne chez Sénégal Tissus', accountId: loisirs.id,
        category: 'Habillement', date: daysAgo(12));
    addExpense(amount: 3500, label: 'Crédit téléphonique', accountId: caisse.id,
        category: 'Communication', date: daysAgo(9));
    addExpense(amount: 21000, label: 'Marché Kermel', accountId: courses.id,
        category: 'Alimentation', date: daysAgo(6));
    addExpense(amount: 5000, label: 'Réparation ventilateur', accountId: imprev.id,
        category: 'Imprévus', date: daysAgo(4));
    addExpense(amount: 13000, label: 'Courses de la semaine', accountId: courses.id,
        category: 'Alimentation', date: daysAgo(2));

    // -- virement vers l'épargne
    transfer(amount: 10000, fromAccountId: caisse.id, toAccountId: epargne.id,
        label: 'Épargne de précaution', date: daysAgo(16));

    // -- achat planifié
    final matelas = addPurchase(
        title: 'Matelas orthopédique', targetCost: 150000, deadline: daysFromNow(60));
    contributePurchase(
        purchaseId: matelas.id, fromAccountId: epargne.id, amount: 60000, date: daysAgo(19));
    contributePurchase(
        purchaseId: matelas.id, fromAccountId: epargne.id, amount: 10000, date: daysAgo(5));

    // -- fonds tiers (fiducie) avec détournement partiel
    final fonds = addFund(
      title: 'Cadeau Mariama',
      owner: 'Maman',
      initialAmount: 50000,
      purpose: 'Achat de tissus pour le baptême',
      deadline: daysFromNow(30),
      date: daysAgo(17),
    );
    spendFund(fundId: fonds.id, amount: 30000, label: 'Tissus chez Ndiaye', date: daysAgo(15));
    divertFund(
        fundId: fonds.id, amount: 10000, destinationAccountId: caisse.id, date: daysAgo(8));
    reimburseFund(fundId: fonds.id, amount: 5000, fromAccountId: caisse.id, date: daysAgo(3));

    // -- tontine (8 membres, moi en position 4)
    final tontine = addTontine(
      name: 'Famille Diop',
      contributionAmount: 10000,
      frequency: TontineFrequency.weekly,
      members: [
        (name: 'Fatou', isMe: false),
        (name: 'Aïssatou', isMe: false),
        (name: 'Moussa', isMe: false),
        (name: 'Moi', isMe: true),
        (name: 'Bineta', isMe: false),
        (name: 'Omar', isMe: false),
        (name: 'Khady', isMe: false),
        (name: 'Ibrahima', isMe: false),
      ],
    );
    for (final d in [daysAgo(21), daysAgo(14), daysAgo(7), daysAgo(2)]) {
      contributeTontine(tontineId: tontine.id, fromAccountId: caisse.id, date: d);
    }
    attributeTontineRound(tontineId: tontine.id, date: daysAgo(20));
    attributeTontineRound(tontineId: tontine.id, date: daysAgo(13));
    attributeTontineRound(tontineId: tontine.id, date: daysAgo(6));

    // -- dettes
    final detteOncle = addDebt(
      creditor: 'Oncle Ibra',
      description: 'Avance pour la réparation du toit',
      principal: 80000,
      fees: 5000,
      dueDate: daysFromNow(45),
      destinationAccountId: caisse.id,
      date: daysAgo(12),
    );
    repayDebt(
        debtId: detteOncle.id,
        amount: 30000,
        fromAccountId: caisse.id,
        note: 'Premier versement',
        date: daysAgo(5));
    addDebt(
      creditor: 'Crédit Express',
      description: 'Micro-crédit pour le commerce de tissus',
      principal: 50000,
      dueDate: daysFromNow(90),
      date: daysAgo(8),
    );

    _commit();
  }
}
