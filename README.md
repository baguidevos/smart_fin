# SamaFi Mobile (SmartFin) 📱💰

[![Release](https://img.shields.io/github/v/release/baguidevos/smart_fin?label=APK%20Release&color=10b981)](https://github.com/baguidevos/smart_fin/releases/latest)
[![Website](https://img.shields.io/badge/Site%20Web-SmartFin-059669)](https://baguidevos.github.io/smart_fin/)
[![License](https://img.shields.io/badge/Licence-Open%20Source-blue)](#)

**Version mobile Flutter de SamaFi (SmartFin)** — gestion financière personnelle intelligente
(devise **FCFA**, interface 100 % française, 100 % hors-ligne).

🌐 **Site officiel & Présentation** : [https://baguidevos.github.io/smart_fin/](https://baguidevos.github.io/smart_fin/)  
📲 **Télécharger l'APK directement** : [SmartFin-v1.1.2.apk](https://github.com/baguidevos/smart_fin/releases/download/v1.1.2/SmartFin-v1.1.2.apk)

> Gestion de routes, d'état et d'injection de dépendances : **GetX**.

---

## ✨ Fonctionnalités

| Module | Description |
| --- | --- |
| 🏠 **Tableau de bord** | Patrimoine net, actif/passifs, épargne, argent du jour, flux 30 j, camembert des dépenses par catégorie, enveloppes, dernières opérations |
| 👛 **Multi-comptes** | Caisses, charges fixes, enveloppes budgétaires, épargne, projets, fiducies, tontines — avec budgets mensuels |
| 📥 **Encaissements ventilés** | Chaque rentrée d'argent est **obligatoirement répartie** sur les comptes (Σ allocations = montant total) |
| 📤 **Dépenses & virements** | Catégories, comptes sources, traçabilité complète |
| 🧾 **Dettes explicites** | Emprunts (capital + frais), remboursements partiels/total, progression jusqu'à solde — *un emprunt n'est pas un revenu* |
| 🤝 **Fonds tiers (fiducie)** | Argent confié par un tiers : dépense objet, détournement tracé, créance interne, reversements |
| 👥 **Tontines** | Cotisations, tours, attribution du pot, encours récupérable |
| 🛍️ **Achats planifiés** | Cagnottes, cotisations, finalisation ou **redirection assumée** des fonds |
| 📜 **Piste d'audit** | Chaque opération porte son explication horodatée (appui long sur une opération dans l'historique) |
| 📤 **Export CSV** | Historique complet partageable |

Toutes les données restent **sur l'appareil** (GetStorage) — aucun réseau, aucun compte.

---

## 🚀 Démarrage rapide

Le dossier contient le projet Dart complet (`lib/` + `pubspec.yaml`). Les
dossiers de plateformes (`android/`, `ios/`, `web/`…) se régénèrent
localement en une commande :

```bash
cd samafi_mobile

# 1. Génère android/, ios/, web/… à partir de lib/ et pubspec.yaml
flutter create . --project-name samafi_mobile --org com.samafi

# 2. Dépendances
flutter pub get

# 3. Lancer (émulateur ou appareil branché)
flutter run
```

**Prérequis** : [Flutter](https://docs.flutter.dev/get-started/install) ≥ 3.19
(Dart ≥ 3.3) avec le SDK Android et/ou Xcode selon la cible.

---

## 🧭 Architecture GetX

L'application démontre les trois piliers de GetX :

| Pilier | Usage dans SamaFi |
| --- | --- |
| **Routage** | `GetMaterialApp` + `AppPages` (table de `GetPage`). Navigation racine : `Get.toNamed(Routes.debtForm)`. **Navigation imbriquée** pour la barre d'onglets : `Navigator(key: Get.nestedKey(ShellNav.id))` + `Get.toNamed(Routes.tabHome, id: ShellNav.id)` |
| **État réactif** | `FinanceRepository` expose des `RxList`/`RxBool` ; les vues rafraîchissent via `Obx(() => …)` sans aucun `setState` |
| **Injection** | `Get.put(FinanceRepository())` au démarrage (service), `Get.lazyPut(() => XController())` dans le `BindingsBuilder` de chaque page — cycle de vie piloté par le routeur |

```
lib/
├── main.dart                → GetStorage.init + Get.put(repo) + GetMaterialApp
├── core/
│   ├── theme.dart           → thème Material 3 émeraude (clair/sombre)
│   ├── format.dart          → fcfa(), dates françaises, parseurs
│   └── constants.dart       → rôles, types, catégories (libellés + icônes)
├── data/
│   ├── models.dart          → comptes, opérations, dettes, tontines…
│   └── repository.dart      → règles métier + audit + persistance
├── routes/
│   ├── app_routes.dart      → noms de routes + onglets (ShellNav)
│   └── app_pages.dart       → table GetPage + bindings lazyPut
├── shared/widgets.dart      → kit UI (StatCard, TxTile, AmountField…)
└── modules/
    ├── splash/  onboarding/  shell/     → démarrage + coque à onglets
    ├── home/  more/                    → tableau de bord, menu « Plus »
    ├── accounts/  history/  movements/ → comptes, historique, formulaires
    ├── debts/  tontines/  funds/  purchases/ → modules métier
    └── settings/                        → profil, thème, export, reset
```

Chaque module suit le découpage GetX canonique :
`<module>_view.dart` (`GetView<XController>`) + `<module>_controller.dart`.

---

## 📐 Règles métier (héritées du cahier des charges)

- **Ventilation obligatoire** — un encaissement doit être intégralement
  réparti : la somme des allocations est vérifiée à la saisie.
- **Un emprunt n'est pas un revenu** — le capital versé sur un compte
  n'alimente pas les flux mensuels ; seul le **passif exigible** augmente.
- **Un remboursement n'est pas une dépense** — il réduit le passif et est
  plafonné au reste à payer.
- **Étanchéité de l'argent des tiers** — les comptes fiduciaires et tontines
  refusent les opérations personnelles ; chaque mouvement est tracé.
- **Créance interne** — tout détournement d'un fonds tiers crée une dette
  envers son propriétaire, déduite du patrimoine net jusqu'à reversement.

**Patrimoine net** = actif disponible (hors fiducies)
− créances internes − dettes restantes.

---

## 🔐 Données & confidentialité

Stockage local `GetStorage` (clé `samafi`). « Réinitialiser » dans
Paramètres → Effacer tout. Un jeu de **données de démonstration** est
proposé à l'écran d'accueil (et dans Paramètres) pour explorer l'app sans
saisie : salaires ventilés, dépenses catégorisées, fiducie avec détournement
partiellement reversé, tontine de 8 membres, deux emprunts dont un en cours
de remboursement.

---

*Projet généré pour SamaFi — Flutter 3.19+, GetX 4.6+, fl_chart, GetStorage, intl, share_plus.*
