/// SamaFi — « Nouvelle dépense » : montant, libellé, compte payeur
/// personnel (sélecteur avec solde), catégorie (chips) et date optionnelle.
/// Le solde et les rôles tiers sont vérifiés par le repository.
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

  final amountCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final selectedAccount = Rx<Account?>(null);
  final category = Rx<String?>(null);
  final date = Rx<DateTime?>(null);

  @override
  void onClose() {
    amountCtrl.dispose();
    labelCtrl.dispose();
    super.onClose();
  }

  void submit() {
    final amount = parseAmount(amountCtrl.text) ?? 0;
    final label = labelCtrl.text.trim();
    if (amount <= 0) {
      errorSnack(AppException('Saisissez le montant de la dépense.'));
      return;
    }
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
      title: 'Nouvelle dépense',
      submitLabel: 'Enregistrer la dépense',
      submitIcon: Icons.north_east,
      onSubmit: c.submit,
      children: [
        AmountField(
          controller: c.amountCtrl,
          label: 'Montant de la dépense',
        ),
        LabeledField(
          label: 'Libellé',
          child: TextFormField(
            controller: c.labelCtrl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration:
                const InputDecoration(hintText: 'Marché, taxi, facture…'),
          ),
        ),
        Obx(() {
          final account = c.selectedAccount.value;
          return LabeledField(
            label: 'Compte payeur',
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showAccountPicker(
                  context,
                  accounts: c.repo.personalAccounts,
                  selectedId: account?.id,
                );
                if (picked != null) c.selectedAccount.value = picked;
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.account_balance,
                    color: account?.role.color ?? cs.onSurfaceVariant,
                  ),
                  suffixIcon: const Icon(Icons.chevron_right, size: 20),
                ),
                child: Text(
                  account == null
                      ? 'Choisir le compte payeur…'
                      : '${account.name} · ${fcfa(account.balance)}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight:
                        account != null ? FontWeight.w700 : FontWeight.w500,
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
            label: 'Catégorie',
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
            label: 'Date de la dépense',
            value: c.date.value,
            onChanged: (d) => c.date.value = d,
            allowEmpty: true,
          ),
        ),
      ],
    );
  }
}
