/// SamaFi — onboarding : présentation des atouts de l'application, saisie du
/// prénom et création des comptes de départ — ou exploration directe avec le
/// scénario de démonstration.
library;

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
              Obx(
                () => OutlinedButton(
                  onPressed: c.busy.value ? null : c.chargerDemo,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Explorer avec la démo'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '6 comptes de départ seront créés : caisse, charges fixes, 3 enveloppes, épargne.',
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
