/// SamaFi — écran phare « Nouvel encaissement » : ventilation obligatoire.
/// Chaque franc encaissé est affecté à un compte (multi-lignes) ; le bandeau
/// temps réel affiche le reste à ventiler (neutre / vert / ambre / rouge) et
/// le bouton « Tout allouer » verse le reste sur la dernière ligne.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

/// Ligne de ventilation : compte destinataire + montant alloué.
class _IncomeLine {
  Account? account;
  final TextEditingController amountCtrl = TextEditingController();
}

class IncomeController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  final totalCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final date = Rx<DateTime?>(null);

  /// Lignes de ventilation (au moins une, ouverte dans onInit).
  final lines = <_IncomeLine>[].obs;

  /// Totaux recalculés à chaque saisie (observés par le bandeau).
  final total = 0.obs;
  final allocated = 0.obs;

  int get reste => total.value - allocated.value;

  @override
  void onInit() {
    super.onInit();
    addLine();
  }

  @override
  void onClose() {
    totalCtrl.dispose();
    labelCtrl.dispose();
    for (final line in lines) {
      line.amountCtrl.dispose();
    }
    super.onClose();
  }

  /// Recalcule total / alloué (appelé onChanged de chaque champ montant).
  void refreshTotals() {
    total.value = parseAmount(totalCtrl.text) ?? 0;
    allocated.value = lines.fold<int>(
        0, (sum, line) => sum + (parseAmount(line.amountCtrl.text) ?? 0));
  }

  void addLine() {
    lines.add(_IncomeLine());
    refreshTotals();
  }

  void removeLine(int index) {
    if (index < 0 || index >= lines.length) return;
    final line = lines.removeAt(index);
    line.amountCtrl.dispose();
    refreshTotals();
  }

  /// Affecte le compte d'une ligne (sélecteur en bottom sheet).
  void setLineAccount(int index, Account account) {
    if (index < 0 || index >= lines.length) return;
    lines[index].account = account;
    lines.refresh();
  }

  /// Verse tout le reste sur la dernière ligne (en crée une s'il n'y en a pas).
  void ventilerTout() {
    if (reste <= 0) return;
    if (lines.isEmpty) {
      addLine();
    }
    final line = lines.last;
    final current = parseAmount(line.amountCtrl.text) ?? 0;
    line.amountCtrl.text = (current + reste).toString();
    refreshTotals();
  }

  void submit() {
    final totalAmount = parseAmount(totalCtrl.text) ?? 0;
    final label = labelCtrl.text.trim();
    if (totalAmount <= 0) {
      errorSnack(AppException("Saisissez d'abord le montant total encaissé."));
      return;
    }
    if (label.isEmpty) {
      errorSnack(AppException('Le libellé est obligatoire.'));
      return;
    }
    for (final line in lines) {
      final amount = parseAmount(line.amountCtrl.text) ?? 0;
      if (line.account == null || amount <= 0) {
        errorSnack(AppException(
            'Complétez chaque ligne de ventilation (compte + montant).'));
        return;
      }
    }
    try {
      repo.addIncome(
        totalAmount: totalAmount,
        label: label,
        allocations: [
          for (final line in lines)
            Allocation(
              accountId: line.account!.id,
              amount: parseAmount(line.amountCtrl.text)!,
            ),
        ],
        date: date.value,
      );
      Get.back();
      successSnack(
        'Encaissement enregistré',
        '${fcfa(totalAmount)} ventilés sur ${lines.length} compte(s)',
      );
    } catch (e) {
      errorSnack(e);
    }
  }
}

class IncomeView extends GetView<IncomeController> {
  const IncomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return FormScaffold(
      title: 'Nouvel encaissement',
      submitLabel: 'Encaisser',
      submitIcon: Icons.south_west,
      onSubmit: c.submit,
      children: [
        AmountField(
          controller: c.totalCtrl,
          label: 'Montant total encaissé',
          onChanged: (_) => c.refreshTotals(),
        ),
        LabeledField(
          label: 'Libellé',
          child: TextFormField(
            controller: c.labelCtrl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration:
                const InputDecoration(hintText: 'Salaire, prime, vente…'),
          ),
        ),
        Obx(
          () => DateField(
            label: "Date de l'encaissement",
            value: c.date.value,
            onChanged: (d) => c.date.value = d,
            allowEmpty: true,
          ),
        ),
        _resteBanner(context),
        const SizedBox(height: 18),
        Text(
          'Ventilation',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Répartissez le montant entre vos comptes.',
          style: TextStyle(
            fontSize: 11.5,
            color: cs.onSurfaceVariant.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => Column(
            children: [
              for (var i = 0; i < c.lines.length; i++) _lineCard(context, i),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: c.addLine,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter une destination'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tips_and_updates_outlined,
                size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Règle d'or : chaque franc encaissé est affecté à un compte (ventilation obligatoire).",
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Bandeau « Reste à ventiler » : neutre si rien saisi, vert si la somme
  /// est intégralement ventilée, ambre s'il reste à affecter, rouge si trop.
  Widget _resteBanner(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final total = c.total.value;
      final allocated = c.allocated.value;
      final reste = total - allocated;
      final Color bg;
      final Color fg;
      final IconData icon;
      final String text;
      if (total == 0) {
        bg = cs.surfaceContainerHighest.withOpacity(0.5);
        fg = cs.onSurfaceVariant;
        icon = Icons.info_outline;
        text = 'Saisissez le montant reçu.';
      } else if (reste == 0) {
        bg = const Color(0xFF059669).withOpacity(0.12);
        fg = const Color(0xFF059669);
        icon = Icons.check_circle;
        text = '${fcfa(total)} intégralement ventilé ✓';
      } else if (reste > 0) {
        bg = const Color(0xFFD97706).withOpacity(0.13);
        fg = const Color(0xFFD97706);
        icon = Icons.warning_amber_rounded;
        text = 'Il reste ${fcfa(reste)} à ventiler';
      } else {
        bg = Colors.red.shade700.withOpacity(0.12);
        fg = Colors.red.shade700;
        icon = Icons.error_outline;
        text = '${fcfa(-reste)} alloués en trop';
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            if (reste > 0)
              TextButton(
                onPressed: c.ventilerTout,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: fg,
                ),
                child: const Text('Tout allouer'),
              ),
          ],
        ),
      );
    });
  }

  /// Carte d'une ligne de ventilation : sélecteur de compte (bottom sheet
  /// sur les comptes personnels) + montant alloué + suppression éventuelle.
  Widget _lineCard(BuildContext context, int index) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    final line = c.lines[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showAccountPicker(
                  context,
                  accounts: c.repo.personalAccounts,
                  selectedId: line.account?.id,
                );
                if (picked != null) c.setLineAccount(index, picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.account_balance,
                    color: line.account?.role.color ?? cs.onSurfaceVariant,
                  ),
                  suffixIcon: const Icon(Icons.chevron_right, size: 20),
                ),
                child: Text(
                  line.account?.name ?? 'Choisir un compte…',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: line.account != null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: line.account != null
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            AmountField(
              controller: line.amountCtrl,
              label: 'Montant alloué',
              onChanged: (_) => c.refreshTotals(),
            ),
            if (c.lines.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => c.removeLine(index),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red.shade700,
                  tooltip: 'Retirer cette destination',
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
