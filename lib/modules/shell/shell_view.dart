/// SamaFi — coque de l'application : navigateur imbriqué à 5 onglets
/// (navigation GetX avec `id: ShellNav.id`), barre de navigation Material 3
/// et bouton d'ajout d'opération (bottom sheet d'aiguillage vers les
/// formulaires de mouvements).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:samafi_mobile/routes/app_pages.dart';
import 'package:samafi_mobile/routes/app_routes.dart';

class ShellController extends GetxController {
  final tabIndex = 0.obs;

  void changeTab(int i) {
    if (i == tabIndex.value || i < 0 || i >= ShellNav.tabs.length) return;
    tabIndex.value = i;
    Get.offNamed(ShellNav.tabs[i], id: ShellNav.id);
  }
}

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      // Le bouton retour ne doit pas fermer la coque : les onglets vivent
      // dans le navigateur imbriqué (id: ShellNav.id).
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final nestedNav = Get.nestedKey(ShellNav.id)?.currentState;
          if (nestedNav != null && nestedNav.canPop()) {
            nestedNav.pop();
            return;
          }
          if (c.tabIndex.value != 0) {
            c.changeTab(0);
          } else {
            SystemNavigator.pop();
          }
        },
        child: Navigator(
          key: Get.nestedKey(ShellNav.id),
          initialRoute: Routes.tabHome,
          onGenerateRoute: (settings) {
            final routeName = (settings.name == null || settings.name == '/')
                ? Routes.tabHome
                : settings.name!;
            final page = AppPages.pages.firstWhere(
              (p) => p.name == routeName,
              orElse: () =>
                  AppPages.pages.firstWhere((p) => p.name == Routes.tabHome),
            );
            return GetPageRoute(
              settings: settings,
              page: page.page,
              binding: page.binding,
              transition: Transition.noTransition,
            );
          },
        ),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: c.tabIndex.value,
          onDestinationSelected: c.changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Comptes',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Historique',
            ),
            NavigationDestination(
              icon: Icon(Icons.request_quote_outlined),
              label: 'Dettes',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              label: 'Plus',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nouvelleOperation(context),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }

  /// Bottom sheet « Nouvelle opération » : aiguillage vers les 4 formulaires
  /// de mouvements (navigateur racine).
  void _nouvelleOperation(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 2),
              child: Text(
                'Nouvelle opération',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _sheetTile(
              icon: Icons.south_west,
              color: Colors.green.shade700,
              title: 'Encaissement',
              subtitle: "Une rentrée d'argent ventilée sur vos comptes",
              route: Routes.incomeForm,
            ),
            _sheetTile(
              icon: Icons.north_east,
              color: Colors.red.shade700,
              title: 'Dépense',
              subtitle: "Une sortie payée depuis l'un de vos comptes",
              route: Routes.expenseForm,
            ),
            _sheetTile(
              icon: Icons.swap_horiz,
              color: cs.primary,
              title: 'Virement',
              subtitle: 'Un transfert entre deux de vos comptes',
              route: Routes.transferForm,
            ),
            _sheetTile(
              icon: Icons.account_balance_outlined,
              color: Colors.orange.shade700,
              title: 'Emprunt',
              subtitle: 'Un capital reçu, à rembourser',
              route: Routes.debtForm,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Get.back();
        Get.toNamed(route);
      },
    );
  }
}
