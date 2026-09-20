/// SamaFi — formulaire « Nouvelle tontine » : nom, cotisation, fréquence et
/// liste éditable des membres (exactement un membre désigné « Moi »).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

String _frequencyLabel(TontineFrequency f) => switch (f) {
      TontineFrequency.daily => "Quotidienne",
      TontineFrequency.weekly => "Hebdomadaire",
      TontineFrequency.monthly => "Mensuelle",
    };

/// Brouillon d'un membre en cours de saisie (nom + drapeau « Moi »).
class MemberDraft {
  final TextEditingController name = TextEditingController();
  final RxBool isMe;

  MemberDraft({bool me = false}) : isMe = me.obs;
}

/// Contrôleur du formulaire de tontine (liste de membres réactive).
class TontineFormController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  final nameCtrl = TextEditingController();
  final contributionCtrl = TextEditingController();
  final frequency = TontineFrequency.weekly.obs;

  /// Cotisation saisie (pour l'aperçu live du pot par tour).
  final contribution = RxInt(0);

  /// Lignes de membres — initial : « Moi » + une ligne vide.
  final members = <MemberDraft>[
    MemberDraft(me: true),
    MemberDraft(),
  ].obs;

  void recomputeContribution() {
    contribution.value = parseAmount(contributionCtrl.text) ?? 0;
  }

  /// Marque [target] comme « Moi » et décoche tous les autres membres.
  void markMe(MemberDraft target) {
    for (final m in members) {
      m.isMe.value = identical(m, target);
    }
  }

  void addMember() => members.add(MemberDraft());

  void removeMember(MemberDraft target) {
    if (members.length <= 2) return;
    members.remove(target);
    target.name.dispose();
  }

  void submit() {
    final name = nameCtrl.text.trim();
    final amount = parseAmount(contributionCtrl.text) ?? 0;
    if (name.isEmpty) {
      errorSnack(AppException("Le nom de la tontine est obligatoire."));
      return;
    }
    if (amount <= 0) {
      errorSnack(AppException(
          "Le montant de la cotisation doit être supérieur à 0 FCFA."));
      return;
    }
    if (members.length < 2) {
      errorSnack(AppException("Une tontine requiert au moins deux membres."));
      return;
    }
    final meCount = members.where((m) => m.isMe.value).length;
    if (meCount != 1) {
      errorSnack(AppException("Désignez exactement un membre « Moi »."));
      return;
    }
    final names = members.map((m) => m.name.text.trim()).toList();
    if (names.any((n) => n.isEmpty)) {
      errorSnack(AppException("Renseignez le nom de chaque membre."));
      return;
    }
    try {
      repo.addTontine(
        name: name,
        contributionAmount: amount,
        frequency: frequency.value,
        members: [
          for (final m in members)
            (name: m.name.text.trim(), isMe: m.isMe.value),
        ],
      );
      Get.back();
      successSnack(
        "Tontine créée",
        "${members.length} membres · ${fcfa(amount * members.length)} par tour",
      );
    } catch (e) {
      errorSnack(e);
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    contributionCtrl.dispose();
    for (final m in members) {
      m.name.dispose();
    }
    super.onClose();
  }
}

/// Écran « Nouvelle tontine ».
class TontineFormView extends GetView<TontineFormController> {
  const TontineFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FormScaffold(
      title: "Nouvelle tontine",
      submitLabel: "Créer la tontine",
      submitIcon: Icons.groups_outlined,
      onSubmit: controller.submit,
      children: [
        LabeledField(
          label: "Nom du cercle",
          child: TextFormField(
            controller: controller.nameCtrl,
            decoration: const InputDecoration(
              hintText: "Famille Diop, collègues…",
            ),
          ),
        ),
        AmountField(
          controller: controller.contributionCtrl,
          label: "Montant de la cotisation",
          onChanged: (_) => controller.recomputeContribution(),
        ),
        LabeledField(
          label: "Fréquence",
          child: Obx(
            () => ChipChoice<TontineFrequency>(
              options: TontineFrequency.values,
              labelOf: _frequencyLabel,
              value: controller.frequency.value,
              onChanged: (f) => controller.frequency.value = f,
            ),
          ),
        ),
        LabeledField(
          label: "Membres",
          hint:
              "L'ordre de saisie définit l'ordre des tours. Désignez exactement un membre comme « Moi ».",
          child: Obx(
            () => Column(
              children: [
                for (final m in controller.members) _memberRow(m),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: controller.addMember,
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text("Ajouter un membre"),
                  ),
                ),
              ],
            ),
          ),
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
                    Icons.savings_outlined,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${controller.members.length} membres · pot de ${fcfa(controller.contribution.value * controller.members.length)} par tour",
                      style: TextStyle(
                        fontSize: 14,
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

  /// Ligne d'un membre : nom + puce « Moi » + suppression (si > 2 membres).
  Widget _memberRow(MemberDraft m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: m.name,
              decoration: const InputDecoration(hintText: "Nom du membre"),
            ),
          ),
          const SizedBox(width: 8),
          Obx(
            () => ChoiceChip(
              label: const Text(
                "Moi",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              selected: m.isMe.value,
              onSelected: (_) => controller.markMe(m),
              showCheckmark: false,
            ),
          ),
          if (controller.members.length > 2)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => controller.removeMember(m),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
