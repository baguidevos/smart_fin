/// SamaFi — onglet « Plus » : carte profil, raccourcis vers les sections
/// avancées (tontines, fonds tiers, achats planifiés, paramètres) et rappel
/// des règles d'or de la comptabilité personnelle.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:samafi_mobile/core/constants.dart';
import 'package:samafi_mobile/core/format.dart';
import 'package:samafi_mobile/data/models.dart';
import 'package:samafi_mobile/data/repository.dart';
import 'package:samafi_mobile/routes/app_routes.dart';
import 'package:samafi_mobile/shared/widgets.dart';

class MoreController extends GetxController {
  final repo = Get.find<FinanceRepository>();
}

/// Initiales affichées dans l'avatar du profil (« Awa Diop » → « AD »).
String _initials(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'S';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return '${words.first.substring(0, 1)}${words[1].substring(0, 1)}'
      .toUpperCase();
}

class MoreView extends GetView<MoreController> {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: Obx(
        () {
          final repo = c.repo;
          final name = repo.profileName.value;
          final tontinesActives = repo.tontines
              .where((t) => t.status == FundStatus.active)
              .length;
          final nbFonds = repo.funds.length;
          final achatsEnPreparation = repo.purchases
              .where((p) => p.status == PurchaseStatus.active)
              .length;
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 96),
            children: [
              // ---- carte profil ------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          _initials(name),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Utilisateur SmartFin' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Patrimoine net : ${fcfa(repo.patrimoineNet)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ---- carte menu ---------------------------------------------
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _menuTile(
                      tint: AccountRole.tontine.color,
                      icon: Icons.groups_outlined,
                      title: 'Tontines',
                      subtitle: '$tontinesActives active(s)',
                      onTap: () => Get.toNamed(Routes.tontines),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _menuTile(
                      tint: AccountRole.fiduciaire.color,
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Fonds tiers',
                      subtitle:
                          '$nbFonds fonds · créance ${fcfa(repo.creancesTotal)}',
                      onTap: () => Get.toNamed(Routes.funds),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _menuTile(
                      tint: AccountRole.project.color,
                      icon: Icons.shopping_bag_outlined,
                      title: 'Achats planifiés',
                      subtitle: '$achatsEnPreparation en préparation',
                      onTap: () => Get.toNamed(Routes.purchases),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _menuTile(
                      tint: cs.primary,
                      icon: Icons.settings_outlined,
                      title: 'Paramètres',
                      subtitle: 'Profil, thème, export, données',
                      onTap: () => Get.toNamed(Routes.settings),
                    ),
                  ],
                ),
              ),
              // ---- rappels des règles d'or ---------------------------------
              const SectionHeader(title: 'Rappels'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 19, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text(
                            "Les règles d'or",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _rule(
                        context,
                        'Un encaissement est toujours ventilé entre vos '
                        'comptes : rien ne reste non affecté.',
                      ),
                      _rule(
                        context,
                        "Un emprunt n'est pas un revenu : c'est un passif "
                        'exigible à rembourser.',
                      ),
                      _rule(
                        context,
                        "L'argent des tiers (fiducies, tontines) reste "
                        'étanche : chaque mouvement est tracé.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  /// Une entrée du menu : icône en pastille teintée + libellé + chevron.
  Widget _menuTile({
    required Color tint,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tint.withOpacity(0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: tint),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// Une ligne de rappel (règle d'or).
  Widget _rule(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 15, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
