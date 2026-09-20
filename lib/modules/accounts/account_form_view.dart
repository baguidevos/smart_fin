/// SamaFi — formulaire de compte : création (nom, rôle, budget mensuel pour
/// les rôles budgetables, solde initial tracé comme encaissement) et édition
/// (nom + budget mensuel ; le rôle et le solde ne sont pas modifiables —
/// l'API du repository ne couvre que ces champs).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

class AccountFormController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Identifiant du compte édité (null → mode création).
  final String? editId = Get.arguments as String?;

  final nameCtrl = TextEditingController();
  final budgetCtrl = TextEditingController();
  final initialCtrl = TextEditingController();
  final selectedRole = Rx<AccountRole?>(null);

  bool get isEdit => editId != null;

  @override
  void onInit() {
    super.onInit();
    if (editId != null) {
      final account = repo.accountById(editId);
      if (account != null) {
        nameCtrl.text = account.name;
        selectedRole.value = account.role;
        budgetCtrl.text = account.monthlyBudget == 0
            ? ''
            : account.monthlyBudget.toString();
      }
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    budgetCtrl.dispose();
    initialCtrl.dispose();
    super.onClose();
  }

  void submit() {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      errorSnack(AppException('Le nom du compte est obligatoire.'));
      return;
    }
    final role = selectedRole.value;
    if (!isEdit && role == null) {
      errorSnack(AppException('Choisissez le rôle du compte.'));
      return;
    }
    try {
      if (isEdit) {
        final roleBudgetable = selectedRole.value?.isBudgetable ?? false;
        repo.updateAccount(
          id: editId!,
          name: name,
          monthlyBudget:
              roleBudgetable ? (parseAmount(budgetCtrl.text) ?? 0) : null,
        );
      } else {
        repo.addAccount(
          name: name,
          role: role!,
          monthlyBudget: parseAmount(budgetCtrl.text) ?? 0,
          initialBalance: parseAmount(initialCtrl.text) ?? 0,
        );
      }
      Get.back();
      if (isEdit) {
        successSnack('Compte mis à jour');
      } else {
        successSnack('Compte créé');
      }
    } catch (e) {
      errorSnack(e);
    }
  }
}

class AccountFormView extends GetView<AccountFormController> {
  const AccountFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return FormScaffold(
      title: c.isEdit ? 'Modifier le compte' : 'Nouveau compte',
      submitLabel: c.isEdit ? 'Enregistrer' : 'Créer le compte',
      submitIcon: c.isEdit ? Icons.check : Icons.add,
      onSubmit: c.submit,
      children: [
        LabeledField(
          label: 'Nom du compte',
          child: TextFormField(
            controller: c.nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Ex. Caisse principale',
            ),
          ),
        ),
        LabeledField(
          label: 'Rôle',
          child: Obx(
            () => Opacity(
              // En édition, le rôle est figé : chips visibles mais inactives.
              opacity: c.isEdit ? 0.55 : 1.0,
              child: IgnorePointer(
                ignoring: c.isEdit,
                child: ChipChoice<AccountRole>(
                  options: AccountRole.values,
                  labelOf: (r) => r.label,
                  value: c.selectedRole.value,
                  onChanged: (r) => c.selectedRole.value = r,
                ),
              ),
            ),
          ),
        ),
        Obx(() {
          final role = c.selectedRole.value;
          if (role == null) return const SizedBox.shrink();
          final suffix = c.isEdit ? ' · rôle non modifiable' : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              '${role.hint}$suffix',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: cs.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          );
        }),
        Obx(() {
          if (c.selectedRole.value?.isBudgetable != true) {
            return const SizedBox.shrink();
          }
          return AmountField(
            controller: c.budgetCtrl,
            label: 'Budget mensuel',
            hint: '0 = non suivi',
          );
        }),
        if (!c.isEdit)
          AmountField(
            controller: c.initialCtrl,
            label: 'Solde initial',
            hint: 'Optionnel — tracé comme encaissement initial',
          ),
      ],
    );
  }
}
