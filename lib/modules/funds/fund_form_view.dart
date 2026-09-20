/// SamaFi — formulaire « Recevoir un fonds tiers » : argent confié par un
/// tiers, objet convenu et échéance de restitution (passif exigible).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

/// Contrôleur du formulaire de réception d'un fonds tiers.
class FundFormController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  final titleCtrl = TextEditingController();
  final ownerCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final purposeCtrl = TextEditingController();
  final date = Rxn<DateTime>();

  void submit() {
    final title = titleCtrl.text.trim();
    final owner = ownerCtrl.text.trim();
    final amount = parseAmount(amountCtrl.text) ?? 0;
    final purpose = purposeCtrl.text.trim();
    if (title.isEmpty) {
      errorSnack(AppException("Le titre du fonds est obligatoire."));
      return;
    }
    if (owner.isEmpty) {
      errorSnack(AppException("Le propriétaire du fonds est obligatoire."));
      return;
    }
    if (amount <= 0) {
      errorSnack(AppException(
          "Le montant initial doit être supérieur à 0 FCFA."));
      return;
    }
    if (purpose.isEmpty) {
      errorSnack(AppException("L'objet du fonds est obligatoire."));
      return;
    }
    try {
      repo.addFund(
        title: title,
        owner: owner,
        initialAmount: amount,
        purpose: purpose,
        deadline: date.value,
      );
      Get.back();
      successSnack(
          "Fonds enregistré", "Vous détenez ${fcfa(amount)} pour $owner");
    } catch (e) {
      errorSnack(e);
    }
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    ownerCtrl.dispose();
    amountCtrl.dispose();
    purposeCtrl.dispose();
    super.onClose();
  }
}

/// Écran « Recevoir un fonds ».
class FundFormView extends GetView<FundFormController> {
  const FundFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FormScaffold(
      title: "Recevoir un fonds",
      submitLabel: "Enregistrer le fonds",
      submitIcon: Icons.volunteer_activism_outlined,
      onSubmit: controller.submit,
      children: [
        LabeledField(
          label: "Titre",
          child: TextFormField(
            controller: controller.titleCtrl,
            decoration: const InputDecoration(
              hintText: "Cadeau Mariama, courses de Khady…",
            ),
          ),
        ),
        LabeledField(
          label: "Qui vous confie cet argent ?",
          child: TextFormField(
            controller: controller.ownerCtrl,
            decoration: const InputDecoration(
              hintText: "Maman, oncle, voisine…",
            ),
          ),
        ),
        AmountField(
          controller: controller.amountCtrl,
          label: "Montant initial",
        ),
        LabeledField(
          label: "Objet convenu",
          child: TextFormField(
            controller: controller.purposeCtrl,
            decoration: const InputDecoration(
              hintText: "Achat de tissus pour le baptême…",
            ),
          ),
        ),
        Obx(
          () => DateField(
            value: controller.date.value,
            onChanged: (d) => controller.date.value = d,
            label: "Date de restitution convenue",
            allowEmpty: true,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Ce montant vous est confié : il n'entre pas dans votre patrimoine (passif exigible).",
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
