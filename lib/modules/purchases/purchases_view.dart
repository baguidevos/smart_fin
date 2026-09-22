/// SamaFi — section « Achats planifiés » : cagnottes à constituer, finalisation
/// payée depuis la cagnotte ou renoncement tracé (redirection de l'argent).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets.dart';

/// Contrôleur de la section Achats planifiés.
class PurchasesController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Vues calculées des achats (cagnotte, cotisations, progression).
  List<PurchaseStat> get stats => repo.purchaseStats;

  /// Cagnottes en constitution.
  List<PurchaseStat> get active => stats
      .where((s) => s.purchase.status == PurchaseStatus.active)
      .toList();

  /// Achats clôturés (achetés, redirigés ou annulés).
  List<PurchaseStat> get closed => stats
      .where((s) => s.purchase.status != PurchaseStatus.active)
      .toList();

  /// Jours restants avant [date] (négatif si l'échéance est dépassée).
  /// Retourne 0 si la date est absente (l'appelant n'affiche alors rien).
  int daysLeft(DateTime? date) {
    if (date == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }
}

/// Écran plein « Achats planifiés ».
class PurchasesView extends GetView<PurchasesController> {
  const PurchasesView({super.key});

  /// Violet des cagnottes (germe du rôle « Projet »).
  static const Color _purple = Color(0xFF7c3aed);

  /// Rouge doux (échéance dépassée).
  static const Color _softRed = Color(0xFFdc2626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Achats planifiés")),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Get.toNamed(Routes.purchaseForm),
        icon: const Icon(Icons.shopping_bag_outlined),
        label: const Text("Planifier un achat"),
      ),
      body: Obx(() {
        if (controller.repo.purchases.isEmpty) {
          return const EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: "Aucun achat planifié",
            message:
                "Constituez des cagnottes : cotisez, finalisez… ou redirigez l'argent vers l'épargne en cas de renoncement.",
          );
        }
        final active = controller.active;
        final closed = controller.closed;
        return ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            for (final stat in active) _activeCard(context, stat),
            if (closed.isNotEmpty) ...[
              const SectionHeader(title: "Clôturés"),
              for (final stat in closed) _closedTile(context, stat),
            ],
          ],
        );
      }),
    );
  }

  // ---- carte d'une cagnotte active ---------------------------------------------

  Widget _activeCard(BuildContext context, PurchaseStat stat) {
    final cs = Theme.of(context).colorScheme;
    final purchase = stat.purchase;
    final deadline = purchase.deadline;
    final days = controller.daysLeft(deadline);
    final pct = (stat.progress * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_outlined,
                      size: 17, color: _purple),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    purchase.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (deadline != null) ...[
                  const SizedBox(width: 8),
                  _deadlineChip(context, deadline, days),
                ],
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (value) => _onMenuSelected(context, stat, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    if (stat.saved == 0)
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red.shade700),
                            const SizedBox(width: 10),
                            Text('Supprimer',
                                style: TextStyle(color: Colors.red.shade700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Cagnotte : ${fcfa(stat.saved)} / ${fcfa(purchase.targetCost)}",
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ProgressTrack(value: stat.progress, color: _purple),
            const SizedBox(height: 5),
            if (stat.remaining > 0)
              Text(
                "$pct % · reste ${fcfa(stat.remaining)}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              Text(
                "Objectif atteint ✓",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            const SizedBox(height: 3),
            Text(
              "${stat.contributionsCount} cotisation(s)",
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openContributeSheet(context, stat),
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: const Text("Cotiser"),
                ),
                OutlinedButton.icon(
                  onPressed: stat.saved >= purchase.targetCost
                      ? () => _onComplete(context, stat)
                      : null,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text("Finaliser"),
                ),
                OutlinedButton.icon(
                  onPressed: () => Get.toNamed(
                    Routes.purchaseForm,
                    arguments: purchase.id,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Modifier"),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amber.shade800,
                  ),
                  onPressed: () => _openRedirectSheet(context, stat),
                  child: const Text("Renoncer & rediriger"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Puce d'échéance : ambre si ≤ 15 jours, rouge si dépassée.
  Widget _deadlineChip(BuildContext context, DateTime deadline, int days) {
    final cs = Theme.of(context).colorScheme;
    final overdue = days < 0;
    final urgent = days >= 0 && days <= 15;
    final color = overdue
        ? _softRed
        : urgent
            ? Colors.amber.shade700
            : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            dateShort(deadline),
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

  void _onMenuSelected(
    BuildContext context,
    PurchaseStat stat,
    String value,
  ) {
    switch (value) {
      case 'edit':
        Get.toNamed(Routes.purchaseForm, arguments: stat.purchase.id);
        break;
      case 'delete':
        _confirmDelete(context, stat);
        break;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PurchaseStat stat,
  ) async {
    final repo = Get.find<FinanceRepository>();
    final purchase = stat.purchase;
    if (stat.saved > 0) {
      errorSnack(AppException(
          "Impossible de supprimer : la cagnotte contient encore ${fcfa(stat.saved)}. Redirigez d'abord les fonds."));
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
      repo.deletePurchase(purchase.id);
      successSnack("Projet supprimé", "« ${purchase.title} » a été supprimé");
    } catch (e) {
      errorSnack(e);
    }
  }

  // ---- cotisation à la cagnotte ---------------------------------------------------

  Future<void> _openContributeSheet(BuildContext context, PurchaseStat stat) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ContributeSheet(stat: stat),
    );
  }

  // ---- finalisation de l'achat ------------------------------------------------------

  Future<void> _onComplete(BuildContext context, PurchaseStat stat) async {
    final repo = Get.find<FinanceRepository>();
    final purchase = stat.purchase;
    final ok = await confirmAction(
      context,
      title: "Finaliser l'achat",
      message:
          "${fcfa(purchase.targetCost)} seront payés depuis la cagnotte « ${purchase.title} ». L'excédent éventuel y reste.",
      confirmLabel: "Finaliser",
    );
    if (!ok) return;
    try {
      repo.completePurchase(purchase.id);
      successSnack(
        "Achat finalisé",
        "${fcfa(purchase.targetCost)} payés — « ${purchase.title} » est à vous.",
      );
    } catch (e) {
      errorSnack(e);
    }
  }

  // ---- renoncement & redirection ------------------------------------------------------

  Future<void> _openRedirectSheet(BuildContext context, PurchaseStat stat) {
    final repo = Get.find<FinanceRepository>();
    final purchase = stat.purchase;
    final selected = Rxn<Account>();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Renoncer & rediriger — ${purchase.title}",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${fcfa(stat.saved)} seront redirigés — décision tracée.",
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(sheetContext)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: "Compte de destination",
                hint: "L'argent de la cagnotte y sera versé.",
                child: _sheetAccountSelector(
                  sheetContext,
                  selected: selected,
                  accounts: repo.personalAccounts,
                  emptyLabel: "Choisir un compte personnel",
                  title: "Compte de destination",
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final account = selected.value;
                    if (account == null) {
                      errorSnack(AppException(
                          "Choisissez le compte de destination."));
                      return;
                    }
                    try {
                      repo.redirectPurchase(
                        purchaseId: purchase.id,
                        destinationAccountId: account.id,
                      );
                      Get.back();
                      successSnack(
                        "Achat renoncé",
                        "${fcfa(stat.saved)} redirigés vers « ${account.name} ».",
                      );
                    } catch (e) {
                      errorSnack(e);
                    }
                  },
                  icon: const Icon(Icons.alt_route_outlined, size: 19),
                  label: const Text("Confirmer la redirection"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- achats clôturés ------------------------------------------------------------------

  Widget _closedTile(BuildContext context, PurchaseStat stat) {
    final cs = Theme.of(context).colorScheme;
    final purchase = stat.purchase;
    var label = "En cours";
    var color = cs.onSurfaceVariant;
    var amount = fcfa(purchase.targetCost);
    switch (purchase.status) {
      case PurchaseStatus.completed:
        label = "Acheté";
        color = Colors.green.shade700;
        amount = fcfa(purchase.targetCost);
      case PurchaseStatus.redirected:
        label = "Redirigé";
        color = _purple;
        amount = "${fcfa(stat.saved)} redirigés";
      case PurchaseStatus.cancelled:
        label = "Annulé";
        color = cs.onSurfaceVariant;
        amount = fcfa(purchase.targetCost);
      case PurchaseStatus.active:
        label = "En cours";
        color = cs.onSurfaceVariant;
        amount = fcfa(purchase.targetCost);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    purchase.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _chip(label, color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              purchase.closedAt != null
                  ? "$amount · ${dateShort(purchase.closedAt!)}"
                  : amount,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- petits helpers partagés dans le fichier ---------------------------------------------

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

/// Sélecteur de compte local à un bottom sheet (Observable + picker + clear).
Widget _sheetAccountSelector(
  BuildContext context, {
  required Rxn<Account> selected,
  required List<Account> accounts,
  required String emptyLabel,
  required String title,
}) {
  final cs = Theme.of(context).colorScheme;
  return Obx(() {
    final account = selected.value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showAccountPicker(
          context,
          accounts: accounts,
          selectedId: account?.id,
          title: title,
        );
        if (picked != null) selected.value = picked;
      },
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: account != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => selected.value = null,
                )
              : const Icon(Icons.account_balance_wallet_outlined, size: 20),
        ),
        child: Text(
          account?.name ?? emptyLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: account != null ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  });
}

class _ContributeSheet extends StatefulWidget {
  final PurchaseStat stat;
  const _ContributeSheet({required this.stat});

  @override
  State<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends State<_ContributeSheet> {
  late final TextEditingController _amountCtrl;
  final _selected = Rxn<Account>();

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Get.find<FinanceRepository>();
    final purchase = widget.stat.purchase;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cotiser — ${purchase.title}",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Cagnotte : ${fcfa(widget.stat.saved)} / ${fcfa(purchase.targetCost)} · reste ${fcfa(widget.stat.remaining)}",
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: "Compte source",
                hint: "D'où part l'argent ?",
                child: _sheetAccountSelector(
                  context,
                  selected: _selected,
                  accounts: repo.personalAccounts,
                  emptyLabel: "Choisir un compte personnel",
                  title: "Compte source",
                ),
              ),
              AmountField(
                controller: _amountCtrl,
                label: "Montant de la cotisation",
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final amount = parseAmount(_amountCtrl.text) ?? 0;
                    final account = _selected.value;
                    if (amount <= 0) {
                      errorSnack(AppException(
                          "La cotisation doit être supérieure à 0 FCFA."));
                      return;
                    }
                    if (account == null) {
                      errorSnack(AppException(
                          "Choisissez le compte source de la cotisation."));
                      return;
                    }
                    try {
                      repo.contributePurchase(
                        purchaseId: purchase.id,
                        fromAccountId: account.id,
                        amount: amount,
                      );
                      Navigator.of(context).pop();
                      successSnack(
                          "Cotisation enregistrée", fcfa(amount));
                    } catch (e) {
                      errorSnack(e);
                    }
                  },
                  icon: const Icon(Icons.check, size: 19),
                  label: const Text("Confirmer la cotisation"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
