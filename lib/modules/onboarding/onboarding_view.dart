/// SamaFi — onboarding : présentation des atouts de l'application, saisie du
/// prénom et création des comptes de départ — ou exploration directe avec le
/// scénario de démonstration.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:samafi_mobile/data/repository.dart';
import 'package:samafi_mobile/routes/app_routes.dart';
import 'package:samafi_mobile/shared/widgets.dart';

class OnboardingController extends GetxController {
  final repo = Get.find<FinanceRepository>();

  final nameCtrl = TextEditingController();
  final busy = false.obs;

  @override
  void onClose() {
    nameCtrl.dispose();
    super.onClose();
  }

  /// Crée le profil et les 6 comptes de départ, puis entre dans la coque.
  void creerComptes() {
    busy.value = true;
    try {
      repo.completeOnboarding(name: nameCtrl.text.trim());
      Get.offNamed(Routes.shell);
    } catch (e) {
      errorSnack(e);
    } finally {
      busy.value = false;
    }
  }

  /// Charge le scénario de démonstration complet (un mois type).
  void chargerDemo() {
    busy.value = true;
    try {
      repo.seedDemo();
      Get.offNamed(Routes.shell);
      successSnack(
        "Données de démonstration chargées",
        "Explorez tous les modules sans rien saisir.",
      );
    } catch (e) {
      errorSnack(e);
    } finally {
      busy.value = false;
    }
  }

  /// Propose le choix entre parcourir les fichiers de l'appareil ou coller du JSON.
  void choisirModeImportation(BuildContext context) {
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
                    'Restaurez l\'ensemble de vos comptes et opérations.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.folder_open_outlined),
              ),
              title: const Text('Sélectionner un fichier .json'),
              subtitle: const Text('Depuis vos téléchargements, Google Drive, etc.'),
              onTap: () {
                Get.back();
                importerFichierJson();
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
                ouvrirDialogueCollerJson(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Sélectionne un fichier JSON sur le smartphone et le restaure.
  Future<void> importerFichierJson() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      busy.value = true;
      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw 'Impossible de lire le fichier de sauvegarde sélectionné.';
      }

      final summary = repo.importBackupJson(content);
      Get.offNamed(Routes.shell);
      successSnack(
        'Sauvegarde restaurée avec succès !',
        'Bonjour ${summary.profileName} : ${summary.accountsCount} comptes et ${summary.transactionsCount} opérations restaurés.',
      );
    } catch (e) {
      errorSnack(e);
    } finally {
      busy.value = false;
    }
  }

  /// Ouvre un dialogue pour coller manuellement le texte JSON.
  void ouvrirDialogueCollerJson(BuildContext context) {
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
                'Collez ci-dessous le contenu JSON de votre sauvegarde (v1.1.0) :',
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
              busy.value = true;
              try {
                final summary = repo.importBackupJson(raw);
                Get.offNamed(Routes.shell);
                successSnack(
                  'Sauvegarde restaurée avec succès !',
                  'Bonjour ${summary.profileName} : ${summary.accountsCount} comptes et ${summary.transactionsCount} opérations restaurés.',
                );
              } catch (e) {
                errorSnack(e);
              } finally {
                busy.value = false;
              }
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }
}

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- hero --------------------------------------------------
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.savings_rounded,
                        size: 38, color: cs.primary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SmartFin',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comptabilité personnelle intelligente — FCFA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ---- atouts ------------------------------------------------
              _benefit(
                context,
                icon: Icons.alt_route_outlined,
                title: 'Ventilation obligatoire des rentrées',
                description:
                    "Chaque encaissement est réparti dès l'arrivée entre la caisse, les charges, les enveloppes et l'épargne.",
              ),
              _benefit(
                context,
                icon: Icons.request_quote_outlined,
                title: 'Dettes & remboursements suivis',
                description:
                    "Un emprunt n'est jamais un revenu : capital, frais et remboursements sont tracés jusqu'au solde.",
              ),
              _benefit(
                context,
                icon: Icons.volunteer_activism_outlined,
                title: 'Argent des tiers étanche (fiducies, tontines)',
                description:
                    "L'argent confié par un tiers reste isolé du vôtre : détournements et créances internes sont tracés.",
              ),
              _benefit(
                context,
                icon: Icons.phone_android_outlined,
                title: "100 % hors-ligne, vos données restent sur l'appareil",
                description:
                    "Aucun compte, aucun réseau : tout est enregistré localement sur votre téléphone.",
              ),
              const SizedBox(height: 8),
              // ---- prénom --------------------------------------------------
              LabeledField(
                label: 'Comment vous appeler ?',
                child: TextFormField(
                  controller: c.nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Votre prénom',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () => FilledButton(
                  onPressed: c.busy.value ? null : c.creerComptes,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Créer mes comptes'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => OutlinedButton(
                        onPressed: c.busy.value ? null : c.chargerDemo,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text('Explorer la démo'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(
                      () => OutlinedButton.icon(
                        onPressed: c.busy.value
                            ? null
                            : () => c.choisirModeImportation(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                        label: const Text('Sauvegarde (v1.1.0)'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Importez une sauvegarde v1.1.0 ou commencez avec 6 comptes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: cs.onSurfaceVariant.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Une ligne d'atout : pastille icône + titre + description.
  Widget _benefit(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
