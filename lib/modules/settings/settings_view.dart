/// SamaFi — paramètres : profil (prénom), apparence (thème sombre), données
/// (export CSV, rechargement de la démo, réinitialisation) et « À propos ».
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'package:samafi_mobile/data/repository.dart';
import 'package:samafi_mobile/routes/app_routes.dart';
import 'package:samafi_mobile/shared/widgets.dart';

class SettingsController extends GetxController {
  final repo = Get.find<FinanceRepository>();

  late final TextEditingController nameCtrl;

  @override
  void onInit() {
    super.onInit();
    nameCtrl = TextEditingController(text: repo.profileName.value);
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    super.onClose();
  }

  /// Enregistre le prénom du profil.
  void saveProfile() {
    try {
      repo.renameProfile(nameCtrl.text.trim());
      successSnack('Profil mis à jour');
    } catch (e) {
      errorSnack(e);
    }
  }

  /// Partage l'historique complet des opérations au format CSV.
  Future<void> exportCsv() async {
    try {
      await Share.share(
        repo.exportTransactionsCsv(),
        subject: 'SamaFi — Historique des opérations',
      );
    } catch (e) {
      errorSnack(e);
    }
  }

  /// Rejoue le scénario de démonstration complet (après confirmation).
  void reloadDemo() {
    try {
      repo.seedDemo();
      successSnack(
        'Données de démonstration rechargées',
        'Le scénario complet a été rejoué.',
      );
    } catch (e) {
      errorSnack(e);
    }
  }

  /// Efface toutes les données et retourne à l'écran d'onboarding.
  void resetApp() {
    try {
      repo.resetAll();
      Get.offNamed(Routes.onboarding);
    } catch (e) {
      errorSnack(e);
    }
  }
}

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        children: [
          // ---- profil --------------------------------------------------
          const SectionHeader(title: 'Profil'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledField(
                    label: 'Prénom',
                    child: TextFormField(
                      controller: c.nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Votre prénom',
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: c.saveProfile,
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ),
          // ---- apparence -------------------------------------------------
          const SectionHeader(title: 'Apparence'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Obx(
              () => SwitchListTile(
                title: const Text('Thème sombre'),
                subtitle: const Text('Émeraude de nuit'),
                value: c.repo.darkMode.value,
                onChanged: (v) => c.repo.setDarkMode(v),
              ),
            ),
          ),
          // ---- données -----------------------------------------------------
          const SectionHeader(title: 'Données'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text("Exporter l'historique (CSV)"),
                  subtitle: const Text(
                    'Toutes les opérations, séparateur « ; »',
                  ),
                  onTap: c.exportCsv,
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Recharger la démo'),
                  subtitle: const Text(
                    'Remplace vos données par le scénario type',
                  ),
                  onTap: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Recharger la démo',
                      message:
                          'Remplacer vos données par le scénario de démonstration ?',
                    );
                    if (ok) c.reloadDemo();
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: Text(
                    "Réinitialiser l'application",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.error,
                    ),
                  ),
                  subtitle: const Text(
                    "Efface toutes les données de l'appareil",
                  ),
                  onTap: () async {
                    final ok = await confirmAction(
                      context,
                      title: "Réinitialiser l'application",
                      message:
                          'Effacer définitivement toutes les données ?',
                      confirmLabel: 'Effacer',
                      destructive: true,
                    );
                    if (ok) c.resetApp();
                  },
                ),
              ],
            ),
          ),
          // ---- à propos -------------------------------------------------
          const SectionHeader(title: 'À propos'),
          const Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Version'),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Technologies'),
                  subtitle: Text('Flutter · GetX · GetStorage · fl_chart'),
                ),
                Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Confidentialité'),
                  subtitle:
                      Text('Toutes les données restent sur votre appareil.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
