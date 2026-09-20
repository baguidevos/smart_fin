/// SamaFi — onglet « Dettes » : carte d'en-tête « Reste à rembourser »,
/// dettes actives avec progression, dettes soldées compactes.
/// Règle métier : un emprunt est un passif exigible, jamais un revenu.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets.dart';

/// Contrôleur de l'onglet Dettes : vues calculées + helpers d'échéance.
class DebtsController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Vues calculées des dettes (soldes, progression, remboursements).
  List<DebtStat> get stats => repo.debtStats;

  /// Dettes en cours de remboursement.
  List<DebtStat> get active => stats.where((s) => !s.settled).toList();

  /// Dettes intégralement remboursées.
  List<DebtStat> get settled => stats.where((s) => s.settled).toList();

  /// Jours restants avant [date] (négatif si l'échéance est dépassée).
  /// Retourne 0 si la date est absente (l'appelant n'affiche alors rien).
  int daysLeft(DateTime? date) {
    if (date == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  /// Échéance la plus proche parmi les dettes actives (null si aucune).
  DateTime? nextDueDate() {
    DateTime? next;
    for (final stat in active) {
      final d = stat.debt.dueDate;
      if (d == null) continue;
      if (next == null || d.isBefore(next)) next = d;
    }
    return next;
  }
}

/// Onglet « Dettes » de la coque : liste, création d'emprunt, remboursement.
class DebtsView extends GetView<DebtsController> {
  const DebtsView({super.key});

  /// Rouge doux (chiffres « Reste » et alertes d'échéance).
  static const Color _softRed = Color(0xFFdc2626);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dettes"),
              Text(
                "${controller.repo.activeDebtCount} active(s) · reste ${fcfa(controller.repo.dettesRemainingTotal)}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Get.toNamed(Routes.debtForm),
        icon: const Icon(Icons.account_balance),
        label: const Text("Nouvel emprunt"),
      ),
      body: Obx(() {
        if (controller.repo.debts.isEmpty) {
          return EmptyState(
            icon: Icons.request_quote_outlined,
            title: "Aucune dette",
            message:
                "Empruntez de l'argent en toute clarté : capital, frais et remboursements suivis jusqu'au dernier franc.",
            actionLabel: "Enregistrer un emprunt",
            onAction: () => Get.toNamed(Routes.debtForm),
          );
        }
        final active = controller.active;
        final settled = controller.settled;
        return ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            _headerCard(active.length, nextDue: controller.nextDueDate()),
            for (final stat in active) _activeDebtCard(context, stat),
            if (settled.isNotEmpty) ...[
              const SectionHeader(title: "Dettes soldées"),
              for (final stat in settled) _settledDebtTile(context, stat),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 12),
              child: Text(
                "Un emprunt n'est pas un revenu : il n'apparaît pas dans vos flux, seulement dans vos passifs.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ---- carte d'en-tête (dégradé rouge doux) -------------------------------

  Widget _headerCard(int activeCount, {DateTime? nextDue}) {
    final remainingTotal = controller.repo.dettesRemainingTotal;
    final repaidTotal = controller.repo.dettesRepaidTotal;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFdc2626), Color(0xFFb91c1c)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Reste à rembourser",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fcfa(remainingTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$activeCount dette(s) en cours · ${fcfa(repaidTotal)} déjà remboursés",
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          if (nextDue != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    "Prochaine échéance : ${dateShort(nextDue)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- carte d'une dette active --------------------------------------------

  Widget _activeDebtCard(BuildContext context, DebtStat stat) {
    final cs = Theme.of(context).colorScheme;
    final debt = stat.debt;
    final days = controller.daysLeft(debt.dueDate);
    final pct = (stat.progress * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    debt.creditor,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _chip(context, "En cours", Colors.amber.shade700),
              ],
            ),
            if (debt.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  debt.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (debt.dueDate != null) ...[
              const SizedBox(height: 10),
              _dueChip(context, debt.dueDate!, days),
            ],
            const SizedBox(height: 12),
            ProgressTrack(value: stat.progress),
            const SizedBox(height: 5),
            Text(
              "$pct % remboursé",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _figure(context, "Emprunté", fcfa(stat.totalDue),
                      cs.onSurface),
                ),
                Expanded(
                  child: _figure(
                      context, "Remboursé", fcfa(stat.repaid), cs.onSurface),
                ),
                Expanded(
                  child: _figure(
                      context, "Reste", fcfa(stat.remaining), _softRed),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        Get.toNamed(Routes.repayForm, arguments: debt.id),
                    icon: const Icon(Icons.payments, size: 18),
                    label: const Text("Rembourser"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Get.toNamed(Routes.debtDetail, arguments: debt.id),
                    child: const Text("Détails"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Puce d'échéance : ambre si ≤ 15 jours, rouge si dépassée.
  Widget _dueChip(BuildContext context, DateTime due, int days) {
    final cs = Theme.of(context).colorScheme;
    final overdue = days < 0;
    final urgent = days >= 0 && days <= 15;
    final color = overdue
        ? _softRed
        : urgent
            ? Colors.amber.shade700
            : cs.onSurfaceVariant;
    final label = overdue ? "En retard de ${-days} j" : "Échéance ${dateShort(due)}";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Colonne de chiffres (libellé + montant).
  Widget _figure(
      BuildContext context, String label, String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  // ---- dettes soldées --------------------------------------------------------

  Widget _settledDebtTile(BuildContext context, DebtStat stat) {
    final cs = Theme.of(context).colorScheme;
    final debt = stat.debt;
    return Card(
      child: ListTile(
        leading: Icon(Icons.check_circle, color: Colors.green.shade700),
        title: Text(
          debt.creditor,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        subtitle: Text(
          debt.settledAt != null
              ? "Soldée le ${dateShort(debt.settledAt!)}"
              : "Soldée",
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Text(
          fcfa(stat.totalDue),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
        onTap: () => Get.toNamed(Routes.debtDetail, arguments: debt.id),
      ),
    );
  }

  // ---- petits helpers --------------------------------------------------------

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
