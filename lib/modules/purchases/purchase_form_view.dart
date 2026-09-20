/// SamaFi — formulaire « Planifier un achat » : titre, coût cible et date
/// d'achat souhaitée ; une cagnotte dédiée est créée à la validation.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

/// Contrôleur du formulaire d'achat planifié.
class PurchaseFormController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  final titleCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final date = Rxn<DateTime>();

  void submit() {
    final title = titleCtrl.text.trim();
    final cost = parseAmount(costCtrl.text) ?? 0;
    if (title.isEmpty) {
      errorSnack(AppException("Le titre de l'achat est obligatoire."));
      return;
    }
    if (cost <= 0) {
      errorSnack(AppException("Le coût cible doit être supérieur à 0 FCFA."));
      return;
    }
    try {
      repo.addPurchase(title: title, targetCost: cost, deadline: date.value);
      Get.back();
      successSnack("Achat planifié", "Cagnotte « $title » créée");
    } catch (e) {
      errorSnack(e);
    }
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    costCtrl.dispose();
    super.onClose();
  }
}

/// Écran « Planifier un achat ».
class PurchaseFormView extends GetView<PurchaseFormController> {
  const PurchaseFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: "Planifier un achat",
      submitLabel: "Créer la cagnotte",
      submitIcon: Icons.flag_outlined,
      onSubmit: controller.submit,
      children: [
        LabeledField(
          label: "Que voulez-vous acheter ?",
          child: TextFormField(
            controller: controller.titleCtrl,
            decoration: const InputDecoration(
              hintText: "Matelas, frigo, smartphone…",
            ),
          ),
        ),
        AmountField(
          controller: controller.costCtrl,
          label: "Coût cible",
        ),
        Obx(
          () => DateField(
            value: controller.date.value,
            onChanged: (d) => controller.date.value = d,
            label: "Date d'achat souhaitée",
            allowEmpty: true,
          ),
        ),
      ],
    );
  }
}
