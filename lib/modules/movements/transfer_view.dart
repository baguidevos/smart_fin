/// SamaFi — « Nouveau virement » : transfert interne entre deux comptes
/// personnels (source ≠ destination et solde suffisant vérifiés par le
/// repository). Le solde de chaque compte choisi est affiché sous le
/// sélecteur ; la source est marquée dans le choix de la destination.
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

  final fromAccount = Rx<Account?>(null);
  final toAccount = Rx<Account?>(null);
  final amountCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final date = Rx<DateTime?>(null);

  @override
  void onClose() {
    amountCtrl.dispose();
    labelCtrl.dispose();
    super.onClose();
  }

  void submit() {
    final from = fromAccount.value;
    final to = toAccount.value;
    if (from == null || to == null) {
      errorSnack(AppException('Choisissez les comptes source et destination.'));
      return;
    }
    final amount = parseAmount(amountCtrl.text) ?? 0;
    if (amount <= 0) {
      errorSnack(AppException('Saisissez le montant du virement.'));
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
    return FormScaffold(
      title: 'Nouveau virement',
      submitLabel: 'Virer',
      submitIcon: Icons.swap_horiz,
      onSubmit: c.submit,
      children: [
        Obx(
          () => _accountSelector(
            context,
            label: 'Compte source',
            emptyHint: 'Choisir le compte source…',
            account: c.fromAccount.value,
            selectedId: c.fromAccount.value?.id,
            onPicked: (account) => c.fromAccount.value = account,
          ),
        ),
        Obx(
          () => _accountSelector(
            context,
            label: 'Compte destination',
            emptyHint: 'Choisir le compte destination…',
            account: c.toAccount.value,
            // La source est marquée dans la liste pour l'éviter en destination.
            selectedId: c.fromAccount.value?.id,
            onPicked: (account) => c.toAccount.value = account,
          ),
        ),
        AmountField(
          controller: c.amountCtrl,
          label: 'Montant du virement',
        ),
        LabeledField(
          label: 'Libellé (optionnel)',
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
            label: 'Date du virement',
            value: c.date.value,
            onChanged: (d) => c.date.value = d,
            allowEmpty: true,
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
            onTap: () async {
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
                suffixIcon: const Icon(Icons.chevron_right, size: 20),
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
