/// SamaFi — « Nouveau virement » / « Modifier le virement » : transfert interne
/// entre deux comptes personnels. En édition, seul le montant est modifiable
/// et les soldes source et destination sont automatiquement réajustés.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

class TransferController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Identifiant du virement en mode édition (null = création).
  final String? editId = Get.arguments as String?;
  bool get isEdit => editId != null;

  final fromAccount = Rx<Account?>(null);
  final toAccount = Rx<Account?>(null);
  final amountCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final date = Rx<DateTime?>(null);

  @override
  void onInit() {
    super.onInit();
    if (editId != null) {
      final tx = repo.transactionById(editId);
      if (tx != null) {
        amountCtrl.text = tx.amount.toString();
        labelCtrl.text = tx.label;
        fromAccount.value = repo.accountById(tx.fromAccountId ?? tx.accountId);
        toAccount.value = repo.accountById(tx.toAccountId);
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
      errorSnack(AppException('Saisissez le montant du virement.'));
      return;
    }

    if (isEdit) {
      try {
        repo.updateTransferAmount(transactionId: editId!, newAmount: amount);
        Get.back();
        successSnack('Virement modifié', 'Nouveau montant : ${fcfa(amount)}');
      } catch (e) {
        errorSnack(e);
      }
      return;
    }

    final from = fromAccount.value;
    final to = toAccount.value;
    if (from == null || to == null) {
      errorSnack(AppException('Choisissez les comptes source et destination.'));
      return;
    }
    final label = labelCtrl.text.trim();
    try {
      repo.transfer(
        amount: amount,
        fromAccountId: from.id,
        toAccountId: to.id,
        label: label.isEmpty ? null : label,
        date: date.value,
      );
      Get.back();
      successSnack('Virement enregistré', '${fcfa(amount)} transférés');
    } catch (e) {
      errorSnack(e);
    }
  }
}

class TransferView extends GetView<TransferController> {
  const TransferView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return FormScaffold(
      title: c.isEdit ? 'Modifier le virement' : 'Nouveau virement',
      submitLabel: c.isEdit ? 'Enregistrer le montant' : 'Virer',
      submitIcon: c.isEdit ? Icons.check : Icons.swap_horiz,
      onSubmit: c.submit,
      children: [
        if (c.isEdit) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Modification du montant de « ${c.labelCtrl.text} ». Les soldes source et destination seront réajustés automatiquement.",
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
          label: c.isEdit ? 'Nouveau montant du virement' : 'Montant du virement',
        ),
        IgnorePointer(
          ignoring: c.isEdit,
          child: Opacity(
            opacity: c.isEdit ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => _accountSelector(
                    context,
                    label: c.isEdit
                        ? 'Compte source (non modifiable)'
                        : 'Compte source',
                    emptyHint: 'Choisir le compte source…',
                    account: c.fromAccount.value,
                    selectedId: c.fromAccount.value?.id,
                    onPicked: (account) => c.fromAccount.value = account,
                  ),
                ),
                Obx(
                  () => _accountSelector(
                    context,
                    label: c.isEdit
                        ? 'Compte destination (non modifiable)'
                        : 'Compte destination',
                    emptyHint: 'Choisir le compte destination…',
                    account: c.toAccount.value,
                    selectedId: c.fromAccount.value?.id,
                    onPicked: (account) => c.toAccount.value = account,
                  ),
                ),
                LabeledField(
                  label: c.isEdit
                      ? 'Libellé (non modifiable)'
                      : 'Libellé (optionnel)',
                  child: TextFormField(
                    controller: c.labelCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration:
                        const InputDecoration(hintText: 'Virement interne'),
                  ),
                ),
                Obx(
                  () => DateField(
                    label: c.isEdit
                        ? 'Date du virement (non modifiable)'
                        : 'Date du virement',
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

  /// Sélecteur de compte (bottom sheet sur les comptes transférables) avec
  /// solde affiché en petit sous le champ lorsque un compte est choisi.
  Widget _accountSelector(
    BuildContext context, {
    required String label,
    required String emptyHint,
    required Account? account,
    required String? selectedId,
    required ValueChanged<Account> onPicked,
  }) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: c.isEdit
                ? null
                : () async {
                    final picked = await showAccountPicker(
                      context,
                      accounts: c.repo.transferableAccounts,
                      selectedId: selectedId,
                    );
                    if (picked != null) onPicked(picked);
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
                account?.name ?? emptyHint,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight:
                      account != null ? FontWeight.w700 : FontWeight.w500,
                  color:
                      account != null ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        if (account != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Solde : ${fcfa(account.balance)}',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
