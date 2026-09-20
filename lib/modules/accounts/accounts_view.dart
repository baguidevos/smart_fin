/// SamaFi — onglet « Comptes » : comptes groupés par rôle dans l'ordre
/// caisses → charges fixes → enveloppes → épargne → projets → fiducies →
/// tontines, section finale « Archivés » (carte grisée) et menu par compte
/// (modifier, archiver/désarchiver, supprimer avec confirmation destructive).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets.dart';

class AccountsController extends GetxController {
  final FinanceRepository repo = Get.find<FinanceRepository>();

  /// Ordre d'affichage des rôles (caisses d'abord, argent de tiers ensuite).
  static const List<AccountRole> roleOrder = [
    AccountRole.wallet,
    AccountRole.budget,
    AccountRole.envelope,
    AccountRole.savings,
    AccountRole.project,
    AccountRole.fiduciaire,
    AccountRole.tontine,
  ];

  /// Comptes non archivés d'un rôle (tri : ordre de création, puis nom).
  List<Account> activeByRole(AccountRole role) {
    final list = repo.accounts
        .where((a) => !a.isArchived && a.role == role)
        .toList();
    list.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return list;
  }

  /// Comptes archivés (section finale, tri alphabétique).
  List<Account> get archivedAccounts {
    final list = repo.accounts.where((a) => a.isArchived).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}

class AccountsView extends GetView<AccountsController> {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = controller.repo;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Comptes'),
              Text(
                '${repo.activeAccounts.length} comptes · actif ${fcfa(repo.actifDisponible)}',
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Get.toNamed(Routes.accountForm),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau compte'),
      ),
      body: Obx(() {
        if (repo.accounts.isEmpty) {
          return EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Aucun compte',
            message: 'Créez votre première caisse ou enveloppe.',
            actionLabel: 'Nouveau compte',
            onAction: () => Get.toNamed(Routes.accountForm),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final role in AccountsController.roleOrder)
              ..._roleSection(controller.activeByRole(role), role),
            ..._archivedSection(context, controller.archivedAccounts),
          ],
        );
      }),
    );
  }

  /// En-tête + carte des comptes actifs d'un rôle (rien si rôle absent).
  List<Widget> _roleSection(List<Account> accounts, AccountRole role) {
    if (accounts.isEmpty) return const <Widget>[];
    return [
      SectionHeader(title: role.label),
      Card(
        child: Column(
          children: [
            for (final account in accounts) _AccountTile(account: account),
          ],
        ),
      ),
    ];
  }

  /// Section finale : comptes archivés (carte grisée, tuiles estompées).
  List<Widget> _archivedSection(BuildContext context, List<Account> archived) {
    if (archived.isEmpty) return const <Widget>[];
    final cs = Theme.of(context).colorScheme;
    return [
      const SectionHeader(title: 'Archivés'),
      Card(
        color: cs.surfaceContainerHighest.withOpacity(0.45),
        child: Column(
          children: [
            for (final account in archived)
              _AccountTile(account: account, archived: true),
          ],
        ),
      ),
    ];
  }
}

/// Tuile d'un compte : avatar teinté du rôle, nom, sous-titre
/// (hint · solde · budget mensuel éventuel), solde en couleur de rôle et
/// menu contextuel (modifier / archiver / supprimer).
class _AccountTile extends StatelessWidget {
  final Account account;
  final bool archived;

  const _AccountTile({required this.account, this.archived = false});

  @override
  Widget build(BuildContext context) {
    final repo = Get.find<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;
    final role = account.role;
    final budgetSuffix = role.isBudgetable && account.monthlyBudget > 0
        ? ' · budget ${fcfa(account.monthlyBudget)}/mois'
        : '';

    final tile = ListTile(
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: role.color.withOpacity(0.13),
        child: Icon(role.icon, size: 19, color: role.color),
      ),
      title: Text(
        account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${role.hint} · ${fcfa(account.balance)}$budgetSuffix',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fcfa(account.balance),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: role.color,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) => _onMenuSelected(context, repo, value),
            itemBuilder: (context) => [
              if (!archived)
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Modifier'),
                ),
              PopupMenuItem<String>(
                value: 'archive',
                child: Text(archived ? 'Désarchiver' : 'Archiver'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  'Supprimer',
                  style: TextStyle(color: cs.error),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => Get.toNamed(Routes.accountForm, arguments: account.id),
    );

    return archived ? Opacity(opacity: 0.6, child: tile) : tile;
  }

  void _onMenuSelected(
      BuildContext context, FinanceRepository repo, String value) {
    switch (value) {
      case 'edit':
        Get.toNamed(Routes.accountForm, arguments: account.id);
        break;
      case 'archive':
        repo.toggleArchive(account.id);
        break;
      case 'delete':
        _confirmDelete(context, repo);
        break;
    }
  }

  /// Suppression : confirmation destructive ; le repository refuse un compte
  /// lié à des opérations ou au solde non nul (message métier en snackbar).
  Future<void> _confirmDelete(
      BuildContext context, FinanceRepository repo) async {
    final confirmed = await confirmAction(
      context,
      title: 'Supprimer « ${account.name} » ?',
      message:
          'Action impossible si le compte est lié à des opérations ou au solde non nul.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      repo.deleteAccount(account.id);
    } catch (e) {
      errorSnack(e);
    }
  }
}
