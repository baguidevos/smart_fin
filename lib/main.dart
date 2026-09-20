/// SamaFi — point d'entrée. GetMaterialApp pilote la navigation (GetX),
/// le thème clair/sombre réactif et l'injection du repository unique.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'data/repository.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Données de formatage françaises (dates littérales : « sam. 8 juin »).
  await initializeDateFormatting('fr_FR');
  // Stockage local unique de toutes les données SamaFi.
  await GetStorage.init(FinanceRepository.storageName);
  // Le repository est un GetxService : disponible partout via Get.find().
  Get.put(FinanceRepository());
  runApp(const SamafiApp());
}

class SamafiApp extends StatelessWidget {
  const SamafiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = Get.find<FinanceRepository>();
    return Obx(
      () => GetMaterialApp(
        title: 'SmartFin',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        fallbackLocale: const Locale('fr', 'FR'),
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('fr'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: SamafiTheme.light(),
        darkTheme: SamafiTheme.dark(),
        themeMode: repo.darkMode.value ? ThemeMode.dark : ThemeMode.light,
        initialRoute: Routes.splash,
        getPages: AppPages.pages,
      ),
    );
  }
}
