/// SamaFi — tableau de bord : carte héros du patrimoine net, indicateurs
/// clés en grille 2×2, flux et dépenses des 30 derniers jours (camembert),
/// enveloppes budgétaires et dernières opérations.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:samafi_mobile/core/format.dart';
import 'package:samafi_mobile/data/models.dart';
import 'package:samafi_mobile/data/repository.dart';
import 'package:samafi_mobile/modules/shell/shell_view.dart';
import 'package:samafi_mobile/shared/widgets.dart';

/// Palette fixe du camembert des dépenses (8 teintes maximum).
const List<Color> _palette = [
  Color(0xFF059669),
  Color(0xFFd97706),
  Color(0xFFea580c),
  Color(0xFF7c3aed),
  Color(0xFFe11d48),
  Color(0xFF0f766e),
  Color(0xFFa16207),
  Color(0xFF64748b),
];

/// Émeraude-600 (germe de la marque) et rouge doux des dépenses.
const Color _emerald = Color(0xFF059669);

class HomeController extends GetxController {
  final repo = Get.find<FinanceRepository>();

  /// Flux de consommation des 30 derniers jours (revenus, dépenses).
  ({int income, int expense}) get flux => repo.flux30j();

  /// Dépenses des 30 derniers jours par catégorie (tri décroissant).
  Map<String, int> get categories => repo.expensesByCategory30j();

  /// Statistiques d'enveloppes (allocation vs consommation, 30 jours).
  List<({Account account, int allocated, int consumed})> get envelopes =>
      repo.envelopeStats30j();

  /// Six dernières opérations enregistrées.
  List<Transaction> get recent => repo.recentTransactions(6);

  /// Raccourci « Tout voir » : saut vers l'onglet Historique de la coque.
  void voirToutHistorique() => Get.find<ShellController>().changeTab(2);
}

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final repo = c.repo;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                repo.profileName.value.isEmpty
                    ? 'Bonjour'
                    : "Bonjour, ${repo.profileName.value}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Voici votre situation financière',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Basculer le thème clair / sombre',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => repo.setDarkMode(!repo.darkMode.value),
          ),
        ],
      ),
      body: Obx(
        () {
          final flux = c.flux;
          final categories = c.categories;
          final envelopes = c.envelopes;
          final recent = c.recent;
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 96),
            children: [
              _heroCard(repo),
              _statsGrid(context, repo),
              _fluxCard(flux),
              const SectionHeader(title: 'Dépenses des 30 jours'),
              _categoriesCard(categories),
              const SectionHeader(title: 'Enveloppes'),
              _envelopesCard(context, envelopes),
              SectionHeader(
                title: 'Dernières opérations',
                actionLabel: 'Tout voir',
                onAction: c.voirToutHistorique,
              ),
              _recentCard(recent),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  // ---- 1. carte héros : patrimoine net ------------------------------------

  Widget _heroCard(FinanceRepository repo) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF059669), Color(0xFF0f766e)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Patrimoine net',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  fcfa(repo.patrimoineNet),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip('Actif', fcfa(repo.actifDisponible)),
                  _heroChip('Passifs', fcfa(repo.passifsExigibles)),
                  _heroChip('Dettes', fcfa(repo.dettesRemainingTotal)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Puce translucide (blanc à 15 %) de la carte héros.
  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ---- 2. grille 2×2 d'indicateurs ----------------------------------------

  Widget _statsGrid(BuildContext context, FinanceRepository repo) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      // Marges de cartes neutralisées localement pour une grille 2×2
      // régulière (les autres attributs du thème de cartes sont conservés).
      child: Theme(
        data: theme.copyWith(
          cardTheme: theme.cardTheme.copyWith(margin: EdgeInsets.zero),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Épargne',
                    value: fcfa(repo.epargneTotal),
                    icon: Icons.savings_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Argent du jour',
                    value: fcfa(repo.budgetJournalier(repo.joursMoisRestants)),
                    icon: Icons.today_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Portefeuille',
                    value: fcfa(repo.portefeuille),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: "Dépensé aujourd'hui",
                    value: fcfa(repo.depenseAujourdHui),
                    icon: Icons.local_fire_department_outlined,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- 3. flux des 30 derniers jours --------------------------------------

  Widget _fluxCard(({int income, int expense}) flux) {
    final max = flux.income >= flux.expense ? flux.income : flux.expense;
    final epargne = flux.income - flux.expense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flux des 30 derniers jours',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _fluxRow(
              label: 'Revenus',
              amount: flux.income,
              max: max,
              color: _emerald,
            ),
            const SizedBox(height: 14),
            _fluxRow(
              label: 'Dépenses',
              amount: flux.expense,
              max: max,
              color: Colors.red.shade400,
            ),
            if (epargne > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.savings_outlined,
                      size: 15, color: _emerald),
                  const SizedBox(width: 6),
                  Text(
                    'Épargné : ${fcfa(epargne)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _emerald,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Une ligne de flux : libellé + montant + barre proportionnelle au
  /// maximum des deux flux.
  Widget _fluxRow({
    required String label,
    required int amount,
    required int max,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              fcfa(amount),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressTrack(value: max > 0 ? amount / max : 0, color: color),
      ],
    );
  }

  // ---- 4. dépenses par catégorie (camembert) -------------------------------

  Widget _categoriesCard(Map<String, int> categories) {
    if (categories.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Aucune dépense sur les 30 derniers jours.',
            style: TextStyle(fontSize: 13.5),
          ),
        ),
      );
    }
    final entries = categories.entries.take(_palette.length).toList();
    final total = entries.fold(0, (s, e) => s + e.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: _palette[i],
                        radius: 13,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _palette[i],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entries[i].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${fcfa(entries[i].value)} · '
                      '${(total > 0 ? entries[i].value / total * 100 : 0).toStringAsFixed(0)} %',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- 5. enveloppes budgétaires --------------------------------------------

  Widget _envelopesCard(
    BuildContext context,
    List<({Account account, int allocated, int consumed})> envelopes,
  ) {
    if (envelopes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            "Aucune enveloppe pour l'instant.",
            style: TextStyle(fontSize: 13.5),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            for (var i = 0; i < envelopes.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _envelopeRow(context, envelopes[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _envelopeRow(
    BuildContext context,
    ({Account account, int allocated, int consumed}) e,
  ) {
    final cs = Theme.of(context).colorScheme;
    final ratio = e.allocated > 0 ? e.consumed / e.allocated : 0.0;
    final tone = ratio < 0.8
        ? _emerald
        : ratio < 1.0
            ? const Color(0xFFd97706)
            : const Color(0xFFdc2626);
    final pct = (ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                e.account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${fcfa(e.consumed)} / ${fcfa(e.allocated)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ProgressTrack(value: ratio, color: tone),
        const SizedBox(height: 5),
        Text(
          '$pct % consommé',
          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  // ---- 6. dernières opérations -----------------------------------------------

  Widget _recentCard(List<Transaction> recent) {
    if (recent.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            "Aucune opération pour l'instant.",
            style: TextStyle(fontSize: 13.5),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [for (final tx in recent) TxTile(tx: tx)],
      ),
    );
  }
}
