/// SamaFi — remboursement d'une dette : montant prérempli au reste exact,
/// compte source optionnel (solde vérifié par le repository) et note libre.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

/// Contrôleur du formulaire de remboursement.
class RepayController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();
  final String debtId = Get.arguments as String;

  /// Vue calculée de la dette (null si introuvable / déjà soldée).
  DebtStat? get stat =>
      repo.debtStats.where((s) => s.debt.id == debtId).firstOrNull;

  late final TextEditingController amountCtrl;
  final noteCtrl = TextEditingController();
  final selectedAccount = Rxn<Account>();

  RepayController() {
    // Préremplissage avec le reste exact à rembourser.
    amountCtrl = TextEditingController(text: "${stat?.remaining ?? 0}");
  }

  void submit() {
    final s = stat;
    if (s == null) {
      errorSnack(AppException("Dette introuvable."));
      return;
    }
    final amount = parseAmount(amountCtrl.text) ?? 0;
    if (amount <= 0) {
      errorSnack(AppException(
          "Le montant du remboursement doit être supérieur à 0 FCFA."));
      return;
    }
    final remainingBefore = s.remaining;
    try {
      repo.repayDebt(
        debtId: debtId,
        amount: amount,
        fromAccountId: selectedAccount.value?.id,
        note: noteCtrl.text.trim(),
      );
      Get.back();
      final newRemaining = remainingBefore - amount;
      if (newRemaining <= 0) {
        successSnack(
          "Dette soldée 🎉",
          "${fcfa(amount)} — plus rien à rembourser à ${s.debt.creditor}",
        );
      } else {
        successSnack(
            "Remboursement enregistré", "Reste ${fcfa(newRemaining)}");
      }
    } catch (e) {
      errorSnack(e);
    }
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }
}

/// Écran « Rembourser {créancier} ».
class RepayView extends GetView<RepayController> {
  const RepayView({super.key});

  /// Rouge doux (résumé « Reste à payer »).
  static const Color _softRed = Color(0xFFdc2626);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stat = controller.stat;
    if (stat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Rembourser")),
        body: EmptyState(
          icon: Icons.search_off,
          title: "Dette introuvable",
          message: "Cette dette n'existe plus ou a déjà été soldée.",
          actionLabel: "Retour",
          onAction: () => Get.back(),
        ),
      );
    }
    return FormScaffold(
      title: "Rembourser ${stat.debt.creditor}",
      submitLabel: "Rembourser",
      submitIcon: Icons.payments,
      onSubmit: controller.submit,
      children: [
        Obx(() {
          final s = controller.stat;
          if (s == null) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softRed.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _softRed.withOpacity(0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Reste à payer : ${fcfa(s.remaining)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _softRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Total dû ${fcfa(s.totalDue)} · déjà remboursé ${fcfa(s.repaid)}",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
        AmountField(
          controller: controller.amountCtrl,
          label: "Montant du remboursement",
          hint: "Maximum : ${fcfa(stat.remaining)}",
        ),
        LabeledField(
          label: "Compte source (optionnel)",
          hint: "D'où part l'argent ?",
          child: _accountSelector(context),
        ),
        LabeledField(
          label: "Note (optionnelle)",
          child: TextFormField(
            controller: controller.noteCtrl,
            decoration: const InputDecoration(
              hintText: "Premier versement, acompte…",
            ),
          ),
        ),
      ],
    );
  }

  /// Sélecteur de compte optionnel + solde affiché dessous.
  Widget _accountSelector(BuildContext context) {
    final repo = controller.repo;
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final account = controller.selectedAccount.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final picked = await showAccountPicker(
                context,
                accounts: repo.personalAccounts,
                selectedId: account?.id,
                title: "Compte source",
              );
              if (picked != null) controller.selectedAccount.value = picked;
            },
            child: InputDecorator(
              decoration: InputDecoration(
                suffixIcon: account != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            controller.selectedAccount.value = null,
                      )
                    : const Icon(Icons.account_balance_wallet_outlined,
                        size: 20),
              ),
              child: Text(
                account?.name ??
                    "Aucun compte — remboursement sans sortie d'argent",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: account != null ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (account != null) ...[
            const SizedBox(height: 5),
            Text(
              "Solde : ${fcfa(repo.accountById(account.id)?.balance ?? account.balance)}",
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    });
  }
}
