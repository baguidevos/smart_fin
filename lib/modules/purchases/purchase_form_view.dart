/// SamaFi — formulaire « Planifier un achat » / « Modifier l'achat » :
/// titre, coût cible (prix) et date d'achat souhaitée. En création, une cagnotte
/// dédiée est créée ; en modification, le projet et l'objectif sont mis à jour.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

/// Contrôleur du formulaire d'achat planifié (création et édition).
class PurchaseFormController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Identifiant de l'achat à éditer (null = création).
  final String? editId = Get.arguments as String?;

  final titleCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final date = Rxn<DateTime>();

  bool get isEdit => editId != null;

  /// Statistique actuelle si en mode édition.
  PurchaseStat? get stat => editId == null
      ? null
      : repo.purchaseStats.where((s) => s.purchase.id == editId).firstOrNull;

  @override
  void onInit() {
    super.onInit();
    if (editId != null) {
      final purchase = repo.purchaseById(editId);
      if (purchase != null) {
        titleCtrl.text = purchase.title;
        costCtrl.text = purchase.targetCost.toString();
        date.value = purchase.deadline;
      }
    }
  }

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
      if (isEdit) {
        repo.updatePurchase(
          id: editId!,
          title: title,
          targetCost: cost,
          deadline: date.value,
        );
        Get.back();
        successSnack("Achat mis à jour", "Projet « $title » ajusté (${fcfa(cost)})");
      } else {
        repo.addPurchase(title: title, targetCost: cost, deadline: date.value);
        Get.back();
        successSnack("Achat planifié", "Cagnotte « $title » créée");
      }
    } catch (e) {
      errorSnack(e);
    }
  }

  /// Confirmation et suppression si aucune cotisation n'est engagée.
  Future<void> confirmDelete(BuildContext context) async {
    if (editId == null) return;
    final purchase = repo.purchaseById(editId);
    if (purchase == null) return;
    final currentStat = stat;
    final saved = currentStat?.saved ?? 0;
    if (saved > 0) {
      errorSnack(AppException(
          "Impossible de supprimer : la cagnotte contient encore ${fcfa(saved)}. Redirigez d'abord les fonds depuis la liste des achats."));
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: "Supprimer « ${purchase.title} » ?",
      message:
          "Cette action supprimera définitivement le projet d'achat et sa cagnotte vide.",
      confirmLabel: "Supprimer",
      destructive: true,
    );
    if (!confirmed) return;
    try {
      repo.deletePurchase(editId!);
      Get.back();
      successSnack("Projet supprimé", "« ${purchase.title} » a été supprimé");
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

/// Écran « Planifier un achat » / « Modifier l'achat ».
class PurchaseFormView extends GetView<PurchaseFormController> {
  const PurchaseFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.isEdit;
    final stat = controller.stat;
    final cs = Theme.of(context).colorScheme;

    return FormScaffold(
      title: isEdit ? "Modifier l'achat" : "Planifier un achat",
      submitLabel: isEdit ? "Enregistrer" : "Créer la cagnotte",
      submitIcon: isEdit ? Icons.check : Icons.flag_outlined,
      onSubmit: controller.submit,
      actions: [
        if (isEdit && (stat?.saved ?? 0) == 0)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Supprimer le projet",
            onPressed: () => controller.confirmDelete(context),
          ),
      ],
      children: [
        if (isEdit && stat != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF7c3aed).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF7c3aed).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Color(0xFF7c3aed),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cagnotte actuelle : ${fcfa(stat.saved)}",
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7c3aed),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.saved > 0
                            ? "Si vous ajustez le prix cible, l'objectif restant et la progression seront recalculés automatiquement."
                            : "Aucune cotisation enregistrée pour le moment. Vous pouvez modifier le montant ou supprimer ce projet.",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
          label: isEdit ? "Nouveau coût cible (prix)" : "Coût cible",
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
