/// SamaFi — détail d'une dette : carte d'identité, soldes et progression,
/// timeline des remboursements et piste d'audit des opérations liées.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets.dart';

/// Contrôleur du détail d'une dette (identifiant transmis en arguments).
class DebtDetailController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();
  final String debtId = Get.arguments as String;

  /// Vue calculée de la dette (null si introuvable).
  DebtStat? get stat =>
      repo.debtStats.where((s) => s.debt.id == debtId).firstOrNull;

  /// Transactions liées à cette dette (emprunt + remboursements).
  List<Transaction> get relatedTransactions =>
      repo.transactions.where((t) => t.debtId == debtId).toList();
}

/// Écran de détail d'une dette.
class DebtDetailView extends GetView<DebtDetailController> {
  const DebtDetailView({super.key});

  /// Rouge doux (chiffre « Reste »).
  static const Color _softRed = Color(0xFFdc2626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.stat?.debt.creditor ?? "Dette")),
      ),
      body: Obx(() {
        final stat = controller.stat;
        if (stat == null) {
          return const EmptyState(
            icon: Icons.search_off,
            title: "Dette introuvable",
            message:
                "Cette dette n'existe plus ou a été supprimée.",
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _identityCard(context, stat),
            _figuresCard(context, stat),
            if (!stat.settled) _repayButton(),
            SectionHeader(title: "Remboursements (${stat.repayments.length})"),
            if (stat.repayments.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 32, 12),
                child: Text(
                  "Aucun remboursement pour l'instant.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              _repaymentTimeline(context, stat.repayments),
            const SectionHeader(title: "Piste d'audit"),
            _auditCard(context),
          ],
        );
      }),
    );
  }

  // ---- carte d'identité ------------------------------------------------------

  Widget _identityCard(BuildContext context, DebtStat stat) {
    final cs = Theme.of(context).colorScheme;
    final debt = stat.debt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                stat.settled
                    ? _chip("Soldée", Colors.green.shade700)
                    : _chip("En cours", Colors.amber.shade700),
              ],
            ),
            if (debt.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                debt.description,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (debt.dueDate != null)
              _infoRow(
                context,
                Icons.event_outlined,
                "Échéance : ${dateShort(debt.dueDate!)}",
              ),
            _infoRow(
              context,
              Icons.account_balance_wallet_outlined,
              stat.destinationAccountName != null
                  ? "Capital versé sur « ${stat.destinationAccountName} »"
                  : "Capital non versé sur un compte",
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- soldes & progression ----------------------------------------------------

  Widget _figuresCard(BuildContext context, DebtStat stat) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _figure(
                      context, "Total dû", fcfa(stat.totalDue), cs.onSurface),
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
            const SizedBox(height: 14),
            ProgressTrack(value: stat.progress),
          ],
        ),
      ),
    );
  }

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
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ---- remboursement -----------------------------------------------------------

  Widget _repayButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: () =>
              Get.toNamed(Routes.repayForm, arguments: controller.debtId),
          icon: const Icon(Icons.payments, size: 19),
          label: const Text("Rembourser"),
        ),
      ),
    );
  }

  // ---- timeline des remboursements ---------------------------------------------

  Widget _repaymentTimeline(
      BuildContext context, List<DebtRepayment> repayments) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            for (var i = 0; i < repayments.length; i++)
              _timelineRow(context, repayments[i], i == repayments.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(BuildContext context, DebtRepayment r, bool last) {
    final repo = controller.repo;
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF059669),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: cs.outlineVariant.withOpacity(0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fcfa(r.amount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        dateMedium(r.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (r.note != null && r.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "« ${r.note} »",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (r.fromAccountId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "depuis « ${repo.accountName(r.fromAccountId) ?? "compte supprimé"} »",
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- piste d'audit --------------------------------------------------------------

  Widget _auditCard(BuildContext context) {
    final txs = controller.relatedTransactions;
    if (txs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 4, 32, 12),
        child: Text(
          "Aucune opération liée.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: [for (final tx in txs) TxTile(tx: tx)],
      ),
    );
  }

  // ---- petits helpers ---------------------------------------------------------------

  Widget _chip(String label, Color color) {
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
