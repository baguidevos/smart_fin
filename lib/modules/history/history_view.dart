/// SamaFi — onglet « Historique » : journal complet des opérations avec
/// filtres par famille (tout, revenus, dépenses, virements, dettes, fiducie,
/// tontines), recherche par libellé et regroupement par jour décroissant.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';

/// Familles de filtres de l'historique (vocabulaire du cahier des charges).
enum HistoryFilter { all, income, expense, transfer, debts, fiducie, tontine }

const Map<HistoryFilter, String> _filterLabels = {
  HistoryFilter.all: 'Tous',
  HistoryFilter.income: 'Revenus',
  HistoryFilter.expense: 'Dépenses',
  HistoryFilter.transfer: 'Virements',
  HistoryFilter.debts: 'Dettes',
  HistoryFilter.fiducie: 'Fiducie',
  HistoryFilter.tontine: 'Tontines',
};

class HistoryController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  final filter = HistoryFilter.all.obs;
  final search = ''.obs;
  final searchCtrl = TextEditingController();

  /// Types d'opérations couverts par chaque filtre (ensemble vide = tout).
  static const Map<HistoryFilter, Set<TxType>> _filterTypes = {
    HistoryFilter.all: <TxType>{},
    HistoryFilter.income: {TxType.income},
    HistoryFilter.expense: {TxType.expense},
    HistoryFilter.transfer: {
      TxType.transfer,
      TxType.contribution,
      TxType.redirection,
    },
    HistoryFilter.debts: {TxType.debtIn, TxType.debtRepay},
    HistoryFilter.fiducie: {
      TxType.tpIn,
      TxType.tpSpend,
      TxType.tpDivert,
      TxType.tpReimburse,
    },
    HistoryFilter.tontine: {TxType.tontineOut, TxType.tontineIn},
  };

  @override
  void onClose() {
    searchCtrl.dispose();
    super.onClose();
  }

  void setSearch(String value) => search.value = value;

  void clearSearch() {
    searchCtrl.clear();
    search.value = '';
  }

  /// Opérations filtrées (famille + recherche sur le libellé), triées par
  /// date décroissante (createdAt départage les opérations d'un même jour).
  List<Transaction> get filtered {
    final types = _filterTypes[filter.value]!;
    final query = search.value.trim().toLowerCase();
    Iterable<Transaction> it = repo.transactions;
    if (types.isNotEmpty) {
      it = it.where((t) => types.contains(t.type));
    }
    if (query.isNotEmpty) {
      it = it.where((t) => t.label.toLowerCase().contains(query));
    }
    final list = it.toList();
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  int get totalCount => filtered.length;

  int get totalAmount => filtered.fold(0, (sum, t) => sum + t.amount);
}

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Historique'),
              Text(
                '${c.totalCount} opérations · ${fcfa(c.totalAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Zone fixe : filtres par famille d'opération.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Obx(
              () => ChipChoice<HistoryFilter>(
                options: HistoryFilter.values,
                labelOf: (f) => _filterLabels[f]!,
                value: c.filter.value,
                onChanged: (f) => c.filter.value = f,
              ),
            ),
          ),
          // Zone fixe : recherche compacte par libellé.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Obx(
              () => TextFormField(
                controller: c.searchCtrl,
                onChanged: c.setSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Rechercher un libellé…',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: c.search.value.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: c.clearSearch,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final items = c.filtered;
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune opération',
                  message: 'Les mouvements apparaîtront ici.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: _dayGroups(cs, items),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Regroupe les opérations par jour : en-tête {dayLabel} (w800) puis une
  /// carte contenant les tuiles du jour.
  List<Widget> _dayGroups(ColorScheme cs, List<Transaction> items) {
    final groups = <MapEntry<DateTime, List<Transaction>>>[];
    for (final tx in items) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (groups.isEmpty || groups.last.key != day) {
        groups.add(MapEntry(day, <Transaction>[tx]));
      } else {
        groups.last.value.add(tx);
      }
    }
    return [
      for (final group in groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            dayLabel(group.key),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [for (final tx in group.value) TxTile(tx: tx)],
          ),
        ),
      ],
    ];
  }
}
