/// SamaFi — paramètres : profil (prénom), apparence (thème sombre), données
/// (export CSV, rechargement de la démo, réinitialisation) et « À propos ».
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
        subject: 'SmartFin — Historique des opérations',
      );
    } catch (e) {
      errorSnack(e);
    }
  }

  /// Exporte la sauvegarde complète de l'application en JSON (v1.1.0).
  Future<void> exportBackup() async {
    try {
      final jsonStr = repo.exportBackupJson();
      await Share.share(
        jsonStr,
        subject: 'SmartFin — Sauvegarde complète (v1.1.0)',
      );
    } catch (e) {
      errorSnack(e);
    }
  }

  /// Propose d'importer une sauvegarde complète depuis un fichier ou texte.
  void importBackup(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importer une sauvegarde (v1.1.0)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Attention : cette opération remplacera les données actuelles.',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.folder_open_outlined),
              ),
              title: const Text('Sélectionner un fichier .json'),
              subtitle: const Text('Depuis vos téléchargements ou le stockage'),
              onTap: () {
                Get.back();
                _importerFichierJson();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.content_paste_outlined),
              ),
              title: const Text('Coller le code JSON'),
              subtitle: const Text('Si vous avez copié le texte de la sauvegarde'),
              onTap: () {
                Get.back();
                _ouvrirDialogueCollerJson(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _importerFichierJson() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw 'Impossible de lire le fichier sélectionné.';
      }
      final summary = repo.importBackupJson(content);
      nameCtrl.text = summary.profileName;
      successSnack(
        'Sauvegarde restaurée !',
        '${summary.accountsCount} comptes et ${summary.transactionsCount} opérations restaurés.',
      );
    } catch (e) {
      errorSnack(e);
    }
  }

  void _ouvrirDialogueCollerJson(BuildContext context) {
    final textCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Coller la sauvegarde'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Collez le code JSON de votre sauvegarde version 1.1.0 :',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{\n  "version": "1.1.0",\n  ...\n}',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final raw = textCtrl.text.trim();
              if (raw.isEmpty) return;
              Get.back();
              try {
                final summary = repo.importBackupJson(raw);
                nameCtrl.text = summary.profileName;
                successSnack(
                  'Sauvegarde restaurée !',
                  '${summary.accountsCount} comptes et ${summary.transactionsCount} opérations restaurés.',
                );
              } catch (e) {
                errorSnack(e);
              }
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  /// Rejoue le scénario de démonstration complet (après confirmation).
  void reloadDemo() {
    try {
      repo.seedDemo();
      nameCtrl.text = repo.profileName.value;
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
          const SectionHeader(title: 'Données & Sauvegardes'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: const Text("Exporter la sauvegarde (JSON v1.1.0)"),
                  subtitle: const Text(
                    'Comptes, opérations, dettes, tontines et fiducies',
                  ),
                  onTap: c.exportBackup,
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text("Importer une sauvegarde (v1.1.0)"),
                  subtitle: const Text(
                    'Restaure vos données depuis un fichier .json ou texte',
                  ),
                  onTap: () => c.importBackup(context),
                ),
                const Divider(indent: 16, endIndent: 16),
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
                    '1.1.0',
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
