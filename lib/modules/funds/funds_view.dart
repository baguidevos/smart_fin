/// SamaFi — section « Fonds tiers » (fiducie) : argent confié par un tiers,
/// dépenses objet, détournements tracés (créances internes) et reversements.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets.dart';

/// Contrôleur de la section Fonds tiers.
class FundsController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Vues calculées des fonds tiers.
  List<FundStat> get stats => repo.fundStats;
}

/// Écran plein « Fonds tiers ».
class FundsView extends GetView<FundsController> {
  const FundsView({super.key});

  /// Rouge doux (bandeau de créance interne).
  static const Color _softRed = Color(0xFFdc2626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fonds tiers")),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Get.toNamed(Routes.fundForm),
        icon: const Icon(Icons.volunteer_activism_outlined),
        label: const Text("Recevoir un fonds"),
      ),
      body: Obx(() {
        if (controller.repo.funds.isEmpty) {
          return const EmptyState(
            icon: Icons.volunteer_activism_outlined,
            title: "Aucun fonds tiers",
            message:
                "Enregistrez l'argent qu'on vous confie : objet tracé, détournements et reversements suivis à la lettre.",
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            for (final stat in controller.stats) _fundCard(context, stat),
          ],
        );
      }),
    );
  }

  // ---- carte d'un fonds --------------------------------------------------------

  Widget _fundCard(BuildContext context, FundStat stat) {
    final cs = Theme.of(context).colorScheme;
    final fund = stat.fund;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fund.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "de ${fund.owner}",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                stat.settled
                    ? _chip("Clôturée", cs.onSurfaceVariant)
                    : _chip("Active", Colors.green.shade700),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Objet : ${fund.purpose}",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Solde détenu : ${fcfa(stat.balance)}",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _fundFigures(context, fund),
            const SizedBox(height: 12),
            if (stat.creance > 0)
              _creanceBanner(context, stat)
            else
              _chip("Aucune créance", Colors.green.shade700),
            if (fund.deadline != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    "Échéance : ${dateShort(fund.deadline!)}",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (fund.status == FundStatus.active) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openSpendSheet(context, stat),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text("Dépenser objet"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openDivertSheet(context, stat),
                    icon: const Icon(Icons.redo, size: 18),
                    label: const Text("Détourner"),
                  ),
                  if (stat.creance > 0)
                    OutlinedButton.icon(
                      onPressed: () => _openReimburseSheet(context, stat),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text("Reverser"),
                    ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _onSettle(context, stat),
                    child: const Text("Clôturer"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tableau compact 2 colonnes : reçu / dépensé / détourné / reversé.
  Widget _fundFigures(BuildContext context, ThirdPartyFund fund) {
    final cs = Theme.of(context).colorScheme;
    Widget cell(String label, String value, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: cell("Reçu", fcfa(fund.initialAmount), cs.onSurface),
              ),
              Expanded(
                child:
                    cell("Dépensé objet", fcfa(fund.spentOnPurpose), cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: cell("Détourné", fcfa(fund.divertedAmount),
                    Colors.amber.shade700),
              ),
              Expanded(
                child:
                    cell("Reversé", fcfa(fund.reimbursedAmount), cs.onSurface),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bandeau rouge doux : créance interne à reverser au propriétaire.
  Widget _creanceBanner(BuildContext context, FundStat stat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _softRed.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _softRed.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: _softRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Créance interne : ${fcfa(stat.creance)} à reverser à ${stat.fund.owner}",
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _softRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- dépense objet -----------------------------------------------------------

  Future<void> _openSpendSheet(BuildContext context, FundStat stat) {
    final repo = Get.find<FinanceRepository>();
    final fund = stat.fund;
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Dépense objet — ${fund.title}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Objet convenu : ${fund.purpose}",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                AmountField(
                  controller: amountCtrl,
                  label: "Montant",
                  hint: "Disponible : ${fcfa(stat.balance)}",
                ),
                LabeledField(
                  label: "Libellé",
                  child: TextFormField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      hintText: "Tissus chez Ndiaye…",
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final amount = parseAmount(amountCtrl.text) ?? 0;
                      final label = labelCtrl.text.trim();
                      if (amount <= 0) {
                        errorSnack(AppException(
                            "La dépense objet doit être supérieure à 0 FCFA."));
                        return;
                      }
                      if (label.isEmpty) {
                        errorSnack(AppException(
                            "Le libellé de la dépense est obligatoire."));
                        return;
                      }
                      try {
                        repo.spendFund(
                          fundId: fund.id,
                          amount: amount,
                          label: label,
                        );
                        Get.back();
                        successSnack(
                          "Dépense objet enregistrée",
                          "${fcfa(amount)} pour « ${fund.purpose} ».",
                        );
                      } catch (e) {
                        errorSnack(e);
                      }
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 19),
                    label: const Text("Enregistrer la dépense"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      amountCtrl.dispose();
      labelCtrl.dispose();
    });
  }

  // ---- détournement (créance interne) ---------------------------------------------

  Future<void> _openDivertSheet(BuildContext context, FundStat stat) {
    final repo = Get.find<FinanceRepository>();
    final fund = stat.fund;
    final amountCtrl = TextEditingController();
    final selected = Rxn<Account>();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Détourner — ${fund.title}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "L'argent part sur un usage personnel : une créance est enregistrée envers ${fund.owner}.",
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                AmountField(
                  controller: amountCtrl,
                  label: "Montant détourné",
                  hint: "Disponible : ${fcfa(stat.balance)}",
                ),
                LabeledField(
                  label: "Compte de destination",
                  child: _sheetAccountSelector(
                    sheetContext,
                    selected: selected,
                    accounts: repo.personalAccounts,
                    emptyLabel: "Choisir un compte personnel",
                    title: "Compte de destination",
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final amount = parseAmount(amountCtrl.text) ?? 0;
                      final account = selected.value;
                      if (amount <= 0) {
                        errorSnack(AppException(
                            "Le montant détourné doit être supérieur à 0 FCFA."));
                        return;
                      }
                      if (account == null) {
                        errorSnack(AppException(
                            "Choisissez le compte de destination du détournement."));
                        return;
                      }
                      try {
                        repo.divertFund(
                          fundId: fund.id,
                          amount: amount,
                          destinationAccountId: account.id,
                        );
                        Get.back();
                        successSnack(
                          "Détournement enregistré",
                          "${fcfa(amount)} vers « ${account.name} » — créance envers ${fund.owner}.",
                        );
                      } catch (e) {
                        errorSnack(e);
                      }
                    },
                    icon: const Icon(Icons.redo, size: 19),
                    label: const Text("Détourner le montant"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(amountCtrl.dispose);
  }

  // ---- reversement de créance --------------------------------------------------------

  Future<void> _openReimburseSheet(BuildContext context, FundStat stat) {
    final repo = Get.find<FinanceRepository>();
    final fund = stat.fund;
    final amountCtrl = TextEditingController();
    final selected = Rxn<Account>();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Reverser — ${fund.title}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Créance envers ${fund.owner} : ${fcfa(stat.creance)}.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                AmountField(
                  controller: amountCtrl,
                  label: "Montant à reverser",
                  hint: "Maximum : ${fcfa(stat.creance)}",
                ),
                LabeledField(
                  label: "Compte source",
                  hint: "D'où part l'argent rendu au fonds ?",
                  child: _sheetAccountSelector(
                    sheetContext,
                    selected: selected,
                    accounts: repo.personalAccounts,
                    emptyLabel: "Choisir un compte personnel",
                    title: "Compte source",
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final amount = parseAmount(amountCtrl.text) ?? 0;
                      final account = selected.value;
                      if (amount <= 0) {
                        errorSnack(AppException(
                            "Le reversement doit être supérieur à 0 FCFA."));
                        return;
                      }
                      if (account == null) {
                        errorSnack(AppException(
                            "Choisissez le compte source du reversement."));
                        return;
                      }
                      try {
                        repo.reimburseFund(
                          fundId: fund.id,
                          amount: amount,
                          fromAccountId: account.id,
                        );
                        Get.back();
                        successSnack(
                          "Reversement enregistré",
                          "${fcfa(amount)} rendus à ${fund.owner}.",
                        );
                      } catch (e) {
                        errorSnack(e);
                      }
                    },
                    icon: const Icon(Icons.undo, size: 19),
                    label: const Text("Reverser"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(amountCtrl.dispose);
  }

  // ---- clôture --------------------------------------------------------------------

  Future<void> _onSettle(BuildContext context, FundStat stat) async {
    final repo = Get.find<FinanceRepository>();
    final fund = stat.fund;
    final ok = await confirmAction(
      context,
      title: "Clôturer « ${fund.title} » ?",
      message:
          "Le solde détenu doit être à zéro et la créance reversée. Cette clôture est définitive.",
      confirmLabel: "Clôturer",
      destructive: true,
    );
    if (!ok) return;
    try {
      repo.settleFund(fund.id);
      successSnack(
        "Fonds clôturé",
        "« ${fund.title} » est archivé — argent de ${fund.owner} restitué.",
      );
    } catch (e) {
      errorSnack(e);
    }
  }
}

// ---- petits helpers partagés dans le fichier ------------------------------------

Widget _chip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.13),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

/// Sélecteur de compte local à un bottom sheet (Observable + picker + clear).
Widget _sheetAccountSelector(
  BuildContext context, {
  required Rxn<Account> selected,
  required List<Account> accounts,
  required String emptyLabel,
  required String title,
}) {
  final cs = Theme.of(context).colorScheme;
  return Obx(() {
    final account = selected.value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showAccountPicker(
          context,
          accounts: accounts,
          selectedId: account?.id,
          title: title,
        );
        if (picked != null) selected.value = picked;
      },
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: account != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => selected.value = null,
                )
              : const Icon(Icons.account_balance_wallet_outlined, size: 20),
        ),
        child: Text(
          account?.name ?? emptyLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: account != null ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  });
}
