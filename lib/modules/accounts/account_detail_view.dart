/// SamaFi — vue détaillée d'un compte : carte héros du solde et budget,
/// statistiques globales (entrées/sorties), graphique mensuel interactif (fl_chart)
/// et journal complet de toutes les opérations concernant le compte.
library;

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets.dart';

/// Données mensuelles agrégées pour le graphique et l'analyse.
class AccountMonthlyStat {
  final DateTime month;
  final String monthKey; // "YYYY-MM"
  final String shortLabel; // "Sept"
  final String fullLabel; // "Septembre 2026"
  final int inflow; // Entrées / crédits
  final int outflow; // Sorties / débits
  final int net; // inflow - outflow

  const AccountMonthlyStat({
    required this.month,
    required this.monthKey,
    required this.shortLabel,
    required this.fullLabel,
    required this.inflow,
    required this.outflow,
    required this.net,
  });
}

class AccountDetailController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();
  final String accountId;

  AccountDetailController({String? accountId})
      : accountId = accountId ?? (Get.arguments as String? ?? '');

  /// Mois sélectionné pour le filtre (null = tout l'historique).
  final selectedMonthKey = Rx<String?>(null);

  Account? get account => repo.accountById(accountId);

  static const _shortMonths = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc',
  ];

  static const _fullMonths = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  /// Détermine si une opération est une entrée d'argent pour ce compte.
  bool isInflow(Transaction tx) {
    if (tx.toAccountId == accountId) return true;
    if (tx.fromAccountId == accountId) return false;
    return tx.type.isCredit;
  }

  /// Toutes les transactions qui concernent ce compte (triées par date décroissante).
  List<Transaction> get allTransactions {
    final list = repo.transactions.where((t) {
      return t.toAccountId == accountId ||
          t.fromAccountId == accountId ||
          t.accountId == accountId;
    }).toList();

    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Transactions affichées (filtrées par mois si un mois est sélectionné).
  List<Transaction> get displayedTransactions {
    final all = allTransactions;
    final key = selectedMonthKey.value;
    if (key == null) return all;
    return all.where((t) {
      final tKey =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      return tKey == key;
    }).toList();
  }

  /// Total cumulé des entrées sur ce compte.
  int get totalInflow =>
      allTransactions.where(isInflow).fold(0, (s, t) => s + t.amount);

  /// Total cumulé des sorties de ce compte.
  int get totalOutflow =>
      allTransactions.where((t) => !isInflow(t)).fold(0, (s, t) => s + t.amount);

  /// Statistiques des 6 derniers mois (du plus ancien au mois en cours).
  List<AccountMonthlyStat> get monthlyStats {
    final now = DateTime.now();
    final result = <AccountMonthlyStat>[];

    for (var i = 5; i >= 0; i--) {
      // Mois cible
      final yearOffset = (now.month - i - 1) ~/ 12;
      final m = ((now.month - i - 1) % 12) + 1;
      final y = now.year + yearOffset;
      final targetDate = DateTime(y, m);
      final key = '$y-${m.toString().padLeft(2, '0')}';

      // Filtrer les transactions du mois
      final txs = allTransactions.where((t) {
        return t.date.year == y && t.date.month == m;
      });

      var inf = 0;
      var outf = 0;
      for (final t in txs) {
        if (isInflow(t)) {
          inf += t.amount;
        } else {
          outf += t.amount;
        }
      }

      result.add(AccountMonthlyStat(
        month: targetDate,
        monthKey: key,
        shortLabel: _shortMonths[m - 1],
        fullLabel: '${_fullMonths[m - 1]} $y',
        inflow: inf,
        outflow: outf,
        net: inf - outf,
      ));
    }

    return result;
  }

  void toggleMonthFilter(String monthKey) {
    if (selectedMonthKey.value == monthKey) {
      selectedMonthKey.value = null; // Désélectionner
    } else {
      selectedMonthKey.value = monthKey;
    }
  }

  void clearFilter() => selectedMonthKey.value = null;
}

class AccountDetailView extends GetView<AccountDetailController> {
  const AccountDetailView({super.key});

  static const Color _inflowColor = Color(0xFF059669); // Émeraude
  static const Color _outflowColor = Color(0xFFe11d48); // Rouge doux

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Obx(() {
      final account = controller.account;
      if (account == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Détail du compte')),
          body: const EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Compte introuvable',
            message: "Ce compte n'existe plus ou a été supprimé.",
          ),
        );
      }

      final role = account.role;
      final stats = controller.monthlyStats;
      final txs = controller.displayedTransactions;
      final selectedKey = controller.selectedMonthKey.value;

      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: role.color.withOpacity(0.15),
                child: Icon(role.icon, size: 15, color: role.color),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier ce compte',
              onPressed: () => Get.toNamed(Routes.accountForm, arguments: account.id),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            // ---- 1. Carte Héros du compte ----------------------------------
            _heroAccountCard(context, account),

            // ---- 2. Indicateurs globaux (Entrées / Sorties / Solde net) ----
            _totalsCard(context),

            // ---- 3. Graphique d'évolution par mois --------------------------
            const SectionHeader(
              title: 'Évolution mensuelle',
              actionLabel: '6 derniers mois',
            ),
            _monthlyChartCard(context, stats, selectedKey),

            // ---- 4. Filtre actif éventuel ----------------------------------
            if (selectedKey != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mois filtré : ${stats.firstWhere((s) => s.monthKey == selectedKey, orElse: () => stats.last).fullLabel}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.clearFilter,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Tout voir'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ---- 5. Historique complet des opérations -----------------------
            SectionHeader(
              title: 'Historique des opérations (${txs.length})',
            ),
            if (txs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 40,
                        color: cs.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selectedKey != null
                            ? 'Aucune opération pour ce mois.'
                            : 'Aucune opération enregistrée sur ce compte.',
                        style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final tx in txs) _accountTxTile(context, tx, account),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  // ---- Carte héros du solde -------------------------------------------------

  Widget _heroAccountCard(BuildContext context, Account account) {
    final role = account.role;
    final budgetStr = role.isBudgetable && account.monthlyBudget > 0
        ? ' · Budget : ${fcfa(account.monthlyBudget)}/mois'
        : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              role.color,
              role.color.withOpacity(0.78),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (account.isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ARCHIVÉ',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Solde disponible',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  fcfa(account.balance),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${role.hint}$budgetStr',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Carte totaux entrées / sorties ---------------------------------------

  Widget _totalsCard(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'Total Entrées',
              value: fcfa(c.totalInflow),
              icon: Icons.arrow_downward_rounded,
              color: _inflowColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              label: 'Total Sorties',
              value: fcfa(c.totalOutflow),
              icon: Icons.arrow_upward_rounded,
              color: _outflowColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Graphique mensuel fl_chart -------------------------------------------

  Widget _monthlyChartCard(
    BuildContext context,
    List<AccountMonthlyStat> stats,
    String? selectedKey,
  ) {
    final cs = Theme.of(context).colorScheme;

    // Déterminer la valeur Y maximale pour l'échelle
    var maxVal = 0;
    for (final s in stats) {
      maxVal = max(maxVal, max(s.inflow, s.outflow));
    }
    final maxY = maxVal > 0 ? (maxVal * 1.25).toDouble() : 10000.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Légende
            Row(
              children: [
                _legendItem('Entrées (crédits)', _inflowColor),
                const SizedBox(width: 16),
                _legendItem('Sorties (débits)', _outflowColor),
              ],
            ),
            const SizedBox(height: 20),

            // BarChart
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 3 : 1,
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: cs.outlineVariant.withOpacity(0.2),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= stats.length) {
                            return const SizedBox.shrink();
                          }
                          final s = stats[idx];
                          final isSelected = s.monthKey == selectedKey;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              s.shortLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: isSelected
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent && response?.spot != null) {
                        final idx = response!.spot!.touchedBarGroupIndex;
                        if (idx >= 0 && idx < stats.length) {
                          controller.toggleMonthFilter(stats[idx].monthKey);
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => cs.surfaceContainerHighest,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final stat = stats[group.x.toInt()];
                        final isEntree = rodIndex == 0;
                        final amount = isEntree ? stat.inflow : stat.outflow;
                        return BarTooltipItem(
                          '${stat.fullLabel}\n',
                          TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                          children: [
                            TextSpan(
                              text: '${isEntree ? "+ " : "- "}${fcfa(amount)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isEntree ? _inflowColor : _outflowColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < stats.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          // Barre 1 : Entrées (vert émeraude)
                          BarChartRodData(
                            toY: stats[i].inflow.toDouble(),
                            color: _inflowColor,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          // Barre 2 : Sorties (rouge doux)
                          BarChartRodData(
                            toY: stats[i].outflow.toDouble(),
                            color: _outflowColor,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Touchez une barre pour filtrer les opérations du mois correspondant.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ---- Tuile d'opération spécifique au compte -------------------------------

  Widget _accountTxTile(BuildContext context, Transaction tx, Account currentAccount) {
    final cs = Theme.of(context).colorScheme;
    final repo = controller.repo;
    final isEntry = controller.isInflow(tx);
    final color = isEntry ? _inflowColor : _outflowColor;

    // Déterminer le compte partenaire si transfert
    String subtitleInfo = dateMedium(tx.date);
    if (tx.fromAccountId != null && tx.fromAccountId == currentAccount.id) {
      final destName = repo.accountName(tx.toAccountId);
      if (destName != null) {
        subtitleInfo += ' · Vers $destName';
      }
    } else if (tx.toAccountId != null && tx.toAccountId == currentAccount.id) {
      final srcName = repo.accountName(tx.fromAccountId);
      if (srcName != null) {
        subtitleInfo += ' · Depuis $srcName';
      }
    }
    if (tx.category != null && tx.category!.isNotEmpty) {
      subtitleInfo += ' · ${tx.category}';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withOpacity(0.12),
        child: Icon(
          isEntry ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          size: 18,
          color: color,
        ),
      ),
      title: Text(
        tx.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        '${tx.type.label} · $subtitleInfo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: Text(
        '${isEntry ? "+ " : "- "}${fcfa(tx.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
          color: color,
        ),
      ),
      onTap: () => showTxDetails(context, tx),
    );
  }
}
