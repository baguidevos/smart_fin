/// SamaFi — « Nouvelle dépense » / « Modifier la dépense » :
/// montant, libellé, compte payeur personnel (sélecteur avec solde),
/// catégorie (chips) et date optionnelle.
/// En édition, seul le montant dépensé est modifiable pour le moment.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

class ExpenseController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Identifiant de la dépense en édition (null = création).
  final String? editId = Get.arguments as String?;
  bool get isEdit => editId != null;

  final amountCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final selectedAccount = Rx<Account?>(null);
  final category = Rx<String?>(null);
  final date = Rx<DateTime?>(null);

  @override
  void onInit() {
    super.onInit();
    if (editId != null) {
      final tx = repo.transactionById(editId);
      if (tx != null) {
        amountCtrl.text = tx.amount.toString();
        labelCtrl.text = tx.label;
        selectedAccount.value =
            repo.accountById(tx.fromAccountId ?? tx.accountId);
        category.value = tx.category;
        date.value = tx.date;
      }
    }
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    labelCtrl.dispose();
    super.onClose();
  }

  void submit() {
    final amount = parseAmount(amountCtrl.text) ?? 0;
    if (amount <= 0) {
      errorSnack(AppException('Saisissez le montant de la dépense.'));
      return;
    }

    if (isEdit) {
      try {
        repo.updateExpenseAmount(transactionId: editId!, newAmount: amount);
        Get.back();
        successSnack('Dépense modifiée', 'Nouveau montant : ${fcfa(amount)}');
      } catch (e) {
        errorSnack(e);
      }
      return;
    }

    final label = labelCtrl.text.trim();
    if (label.isEmpty) {
      errorSnack(AppException('Le libellé est obligatoire.'));
      return;
    }
    final account = selectedAccount.value;
    if (account == null) {
      errorSnack(AppException('Choisissez le compte payeur.'));
      return;
    }
    try {
      repo.addExpense(
        amount: amount,
        label: label,
        accountId: account.id,
        category: category.value,
        date: date.value,
      );
      Get.back();
      successSnack('Dépense enregistrée', fcfa(amount));
    } catch (e) {
      errorSnack(e);
    }
  }
}

class ExpenseView extends GetView<ExpenseController> {
  const ExpenseView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return FormScaffold(
      title: c.isEdit ? 'Modifier la dépense' : 'Nouvelle dépense',
      submitLabel: c.isEdit ? 'Enregistrer le montant' : 'Enregistrer la dépense',
      submitIcon: c.isEdit ? Icons.check : Icons.north_east,
      onSubmit: c.submit,
      children: [
        if (c.isEdit) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade700.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.shade700.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Modification du montant de « ${c.labelCtrl.text} ». Le solde du compte payeur sera ajusté automatiquement selon la différence.",
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        AmountField(
          controller: c.amountCtrl,
          label: c.isEdit ? 'Nouveau montant dépensé' : 'Montant de la dépense',
        ),
        IgnorePointer(
          ignoring: c.isEdit,
          child: Opacity(
            opacity: c.isEdit ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: c.isEdit ? 'Libellé (non modifiable)' : 'Libellé',
                  child: TextFormField(
                    controller: c.labelCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Marché, taxi, facture…',
                    ),
                  ),
                ),
                Obx(() {
                  final account = c.selectedAccount.value;
                  return LabeledField(
                    label: c.isEdit
                        ? 'Compte payeur (non modifiable)'
                        : 'Compte payeur',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: c.isEdit
                          ? null
                          : () async {
                              final picked = await showAccountPicker(
                                context,
                                accounts: c.repo.personalAccounts,
                                selectedId: account?.id,
                              );
                              if (picked != null) {
                                c.selectedAccount.value = picked;
                              }
                            },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.account_balance,
                            color: account?.role.color ?? cs.onSurfaceVariant,
                          ),
                          suffixIcon: c.isEdit
                              ? null
                              : const Icon(Icons.chevron_right, size: 20),
                        ),
                        child: Text(
                          account == null
                              ? 'Choisir le compte payeur…'
                              : '${account.name} · ${fcfa(account.balance)}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: account != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: account != null
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                Obx(
                  () => LabeledField(
                    label: c.isEdit
                        ? 'Catégorie (non modifiable)'
                        : 'Catégorie',
                    child: ChipChoice<String>(
                      options: [for (final cat in kExpenseCategories) cat.label],
                      labelOf: (label) => label,
                      value: c.category.value,
                      onChanged: (label) => c.category.value = label,
                    ),
                  ),
                ),
                Obx(
                  () => DateField(
                    label: c.isEdit
                        ? 'Date de la dépense (non modifiable)'
                        : 'Date de la dépense',
                    value: c.date.value,
                    onChanged: (d) => c.date.value = d,
                    allowEmpty: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
