/// SamaFi — formulaire « Nouvel emprunt » : créancier, motif, capital, frais,
/// échéance et versement optionnel du capital sur un compte personnel.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

/// Contrôleur du formulaire d'emprunt ( validations locales + aperçu live).
class DebtFormController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  final creditorCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final principalCtrl = TextEditingController();
  final feesCtrl = TextEditingController();

  final date = Rxn<DateTime>();
  final selectedAccount = Rxn<Account>();

  /// Total à rembourser (capital + frais) pour l'aperçu live.
  final previewTotal = RxInt(0);

  /// Recalcule l'aperçu « Total à rembourser » après chaque saisie.
  void recomputePreview() {
    final principal = parseAmount(principalCtrl.text) ?? 0;
    final fees = parseAmount(feesCtrl.text) ?? 0;
    previewTotal.value = principal + fees;
  }

  void submit() {
    final creditor = creditorCtrl.text.trim();
    final description = descriptionCtrl.text.trim();
    final principal = parseAmount(principalCtrl.text) ?? 0;
    if (creditor.isEmpty) {
      errorSnack(AppException("Le créancier est obligatoire."));
      return;
    }
    if (description.isEmpty) {
      errorSnack(AppException("Le motif de l'emprunt est obligatoire."));
      return;
    }
    if (principal <= 0) {
      errorSnack(AppException("Le capital reçu doit être supérieur à 0 FCFA."));
      return;
    }
    try {
      final debt = repo.addDebt(
        creditor: creditor,
        description: description,
        principal: principal,
        fees: parseAmount(feesCtrl.text) ?? 0,
        dueDate: date.value,
        destinationAccountId: selectedAccount.value?.id,
      );
      Get.back();
      successSnack("Emprunt enregistré", "Total dû : ${fcfa(debt.totalDue)}");
    } catch (e) {
      errorSnack(e);
    }
  }

  @override
  void onClose() {
    creditorCtrl.dispose();
    descriptionCtrl.dispose();
    principalCtrl.dispose();
    feesCtrl.dispose();
    super.onClose();
  }
}

/// Écran « Nouvel emprunt ».
class DebtFormView extends GetView<DebtFormController> {
  const DebtFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FormScaffold(
      title: "Nouvel emprunt",
      submitLabel: "Enregistrer l'emprunt",
      submitIcon: Icons.account_balance,
      onSubmit: controller.submit,
      children: [
        LabeledField(
          label: "À qui devez-vous cet argent ?",
          child: TextFormField(
            controller: controller.creditorCtrl,
            decoration: const InputDecoration(
              hintText: "Oncle, amie, institution…",
            ),
          ),
        ),
        LabeledField(
          label: "Motif de l'emprunt",
          child: TextFormField(
            controller: controller.descriptionCtrl,
            decoration: const InputDecoration(
              hintText: "Réparation du toit, stock de tissus…",
            ),
          ),
        ),
        AmountField(
          controller: controller.principalCtrl,
          label: "Capital reçu",
          onChanged: (_) => controller.recomputePreview(),
        ),
        AmountField(
          controller: controller.feesCtrl,
          label: "Frais ou intérêts convenus",
          hint: "Optionnel — ajoutés au total dû",
          onChanged: (_) => controller.recomputePreview(),
        ),
        Obx(
          () => DateField(
            value: controller.date.value,
            onChanged: (d) => controller.date.value = d,
            label: "Date de remboursement convenue",
            allowEmpty: true,
          ),
        ),
        LabeledField(
          label: "Verser le capital sur un compte ?",
          hint: "Optionnel — le capital créditera directement ce compte.",
          child: _accountSelector(context),
        ),
        const SizedBox(height: 4),
        Obx(
          () => Card(
            margin: EdgeInsets.zero,
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Total à rembourser : ${fcfa(controller.previewTotal.value)}",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sélecteur de compte optionnel (bottom sheet + bouton d'effacement).
  Widget _accountSelector(BuildContext context) {
    final repo = controller.repo;
    return Obx(
      () => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final account = await showAccountPicker(
            context,
            accounts: repo.personalAccounts,
            selectedId: controller.selectedAccount.value?.id,
            title: "Compte de versement",
          );
          if (account != null) controller.selectedAccount.value = account;
        },
        child: InputDecorator(
          decoration: InputDecoration(
            suffixIcon: controller.selectedAccount.value != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => controller.selectedAccount.value = null,
                  )
                : const Icon(Icons.account_balance_wallet_outlined, size: 20),
          ),
          child: Text(
            controller.selectedAccount.value?.name ??
                "Aucun — garder le capital hors comptes",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: controller.selectedAccount.value != null
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
