/// SamaFi — écran d'accueil (splash) : identité émeraude affichée le temps
/// du démarrage, puis aiguillage vers l'onboarding (première visite) ou la
/// coque à onglets.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:samafi_mobile/data/repository.dart';
import 'package:samafi_mobile/routes/app_routes.dart';

class SplashController extends GetxController {
  final repo = Get.find<FinanceRepository>();

  /// Vrai tant que l'écran est affiché : l'indicateur de chargement
  /// disparaît juste avant la navigation.
  final visible = true.obs;

  @override
  void onReady() {
    super.onReady();
    Future.delayed(const Duration(milliseconds: 1600), () {
      visible.value = false;
      Get.offNamed(repo.onboarded.value ? Routes.shell : Routes.onboarding);
    });
  }
}

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    // L'accès au contrôleur déclenche son instanciation (lazyPut du binding)
    // et donc sa méthode onReady, qui programme la navigation temporisée.
    final c = controller;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF059669), Color(0xFF0f766e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              // Logo : cercle blanc translucide + icône épargne.
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'SamaFi',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Votre argent, clairement.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
              const Spacer(flex: 4),
              // Petit indicateur de chargement blanc, masqué au départ.
              Obx(
                () => SizedBox(
                  height: 26,
                  width: 26,
                  child: c.visible.value
                      ? const CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
