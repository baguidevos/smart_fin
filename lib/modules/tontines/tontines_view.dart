/// SamaFi — section « Tontines » : cercles de cotisations, progression des
/// tours, encours personnel, cotisations tracées et attribution du pot.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets.dart';

String _frequencyLabel(TontineFrequency f) => switch (f) {
      TontineFrequency.daily => "Quotidienne",
      TontineFrequency.weekly => "Hebdomadaire",
      TontineFrequency.monthly => "Mensuelle",
    };

/// Initiales d'un membre (2 lettres maximum) pour les pastilles.
String _initials(String name) {
  final clean = name.trim();
  if (clean.isEmpty) return "?";
  final parts = clean.split(RegExp(r"\s+"));
  final first = parts.first.substring(0, 1).toUpperCase();
  final second =
      parts.length > 1 ? parts.last.substring(0, 1).toUpperCase() : "";
  return second.isEmpty ? first : "$first$second";
}

/// Contrôleur de la section Tontines.
class TontinesController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();
}

/// Écran plein « Tontines ».
class TontinesView extends GetView<TontinesController> {
  const TontinesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tontines")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(Routes.tontineForm),
        icon: const Icon(Icons.groups_outlined),
        label: const Text("Nouvelle tontine"),
      ),
      body: Obx(() {
        if (controller.repo.tontines.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_outlined,
            title: "Aucune tontine",
            message:
                "Créez votre cercle de cotisations : membres, montant, tours.",
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            for (final t in controller.repo.tontines) _tontineCard(context, t),
          ],
        );
      }),
    );
  }

  // ---- carte d'une tontine ---------------------------------------------------

  Widget _tontineCard(BuildContext context, Tontine t) {
    final repo = controller.repo;
    final cs = Theme.of(context).colorScheme;
    final balance = repo.accountById(t.accountId)?.balance ?? 0;
    final me = t.me;
    final members = [...t.members]
      ..sort((a, b) => a.position.compareTo(b.position));
    final pot = t.contributionAmount * t.totalRounds;
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
                    t.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _chip(_frequencyLabel(t.frequency), cs.primary),
                if (t.status == FundStatus.settled) ...[
                  const SizedBox(width: 6),
                  _chip("Terminée", cs.onSurfaceVariant),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Cotisation : ${fcfa(t.contributionAmount)} · Pot complet : ${fcfa(pot)}",
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              "Tour ${t.currentRound}/${t.totalRounds}",
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            ProgressTrack(
              value: t.totalRounds > 0 ? t.currentRound / t.totalRounds : 0.0,
            ),
            const SizedBox(height: 12),
            Text(
              "Mon encours : ${fcfa(balance)}",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (me != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Moi : position ${me.position}",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (me.hasReceived)
                    _chip("Tour reçu ✓", Colors.green.shade700)
                  else
                    _chip(
                        "Mon tour dans ${t.nextMyRound ?? 0} tour(s)",
                        Colors.amber.shade700),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in members) _memberPill(context, m),
              ],
            ),
            if (t.status == FundStatus.active) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openContributeSheet(context, t),
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: const Text("Cotiser"),
                  ),
                  if (t.currentRound < t.totalRounds)
                    OutlinedButton.icon(
                      onPressed: () => _onAttributeTap(context, t),
                      icon: const Icon(Icons.emoji_events_outlined, size: 18),
                      label: const Text("Attribuer le tour suivant"),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pastille d'un membre : initiales, nom, coche verte si tour reçu.
  Widget _memberPill(BuildContext context, TontineMember m) {
    final cs = Theme.of(context).colorScheme;
    final tint = m.isMe ? cs.primary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: tint.withOpacity(0.22),
            child: Text(
              _initials(m.name),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "${m.name}${m.isMe ? " (moi)" : ""}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          if (m.hasReceived) ...[
            const SizedBox(width: 4),
            Icon(Icons.check, size: 13, color: Colors.green.shade700),
          ],
        ],
      ),
    );
  }

  // ---- cotisation ----------------------------------------------------------------

  Future<void> _openContributeSheet(BuildContext context, Tontine t) {
    final repo = Get.find<FinanceRepository>();
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
                "Cotiser à ${t.name} — ${fcfa(t.contributionAmount)}",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: "Compte source",
                hint: "D'où part la cotisation ?",
                child: _sheetAccountSelector(
                  sheetContext,
                  selected: selected,
                  accounts: repo.personalAccounts,
                  emptyLabel: "Choisir un compte personnel",
                  title: "Compte source",
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final account = selected.value;
                    if (account == null) {
                      errorSnack(AppException(
                          "Choisissez le compte source de la cotisation."));
                      return;
                    }
                    try {
                      repo.contributeTontine(
                        tontineId: t.id,
                        fromAccountId: account.id,
                      );
                      Get.back();
                      successSnack(
                          "Cotisation enregistrée", fcfa(t.contributionAmount));
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

  // ---- attribution du tour suivant --------------------------------------------------

  Future<void> _onAttributeTap(BuildContext context, Tontine t) async {
    final repo = Get.find<FinanceRepository>();
    final next = t.members
        .where((m) => m.position == t.currentRound + 1)
        .firstOrNull;
    if (next == null) return;
    if (next.isMe) {
      await _openReceivePotSheet(context, t);
      return;
    }
    final round = t.currentRound + 1;
    final ok = await confirmAction(
      context,
      title: "Attribuer le tour $round",
      message:
          "Le tour revient à ${next.name}. Ma cotisation du tour (${fcfa(t.contributionAmount)}) quitte la cagnotte.",
      confirmLabel: "Attribuer",
    );
    if (!ok) return;
    try {
      repo.attributeTontineRound(tontineId: t.id);
      successSnack("Tour attribué", "Le tour $round revient à ${next.name}.");
    } catch (e) {
      errorSnack(e);
    }
  }

  /// « C'est mon tour ! » : choix du compte personnel qui reçoit le pot.
  Future<void> _openReceivePotSheet(BuildContext context, Tontine t) {
    final repo = Get.find<FinanceRepository>();
    final selected = Rxn<Account>();
    final pot = t.contributionAmount * t.totalRounds;
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
              const Text(
                "C'est mon tour !",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Recevez le pot complet de « ${t.name} » : ${fcfa(pot)}.",
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: "Compte de réception",
                hint: "Le pot sera crédité sur ce compte personnel.",
                child: _sheetAccountSelector(
                  sheetContext,
                  selected: selected,
                  accounts: repo.personalAccounts,
                  emptyLabel: "Choisir un compte personnel",
                  title: "Compte de réception",
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final account = selected.value;
                    if (account == null) {
                      errorSnack(AppException(
                          "Choisissez le compte personnel qui recevra le pot."));
                      return;
                    }
                    try {
                      repo.attributeTontineRound(
                        tontineId: t.id,
                        destinationAccountId: account.id,
                      );
                      Get.back();
                      successSnack(
                        "Pot reçu 🎉",
                        "${fcfa(pot)} crédités sur « ${account.name} ».",
                      );
                    } catch (e) {
                      errorSnack(e);
                    }
                  },
                  icon: const Icon(Icons.emoji_events_outlined, size: 19),
                  label: Text("Recevoir le pot (${fcfa(pot)})"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- petits helpers ------------------------------------------------------------

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
