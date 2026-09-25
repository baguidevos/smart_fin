# Journal des modifications (Changelog) — SmartFin

Toutes les modifications notables de l'application SmartFin (SamaFi Mobile) sont documentées dans ce fichier.
Le format est inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/) et ce projet adhère à la [Gestion sémantique de version](https://semver.org/lang/fr/).

---

## [1.2.3] - 2026-09-25

### Ajouté & Amélioré
- **Détail complet d'un compte au clic dans l'onglet Comptes (`AccountDetailView`)** :
  - En appuyant sur n'importe quel compte dans l'onglet **Comptes**, ouverture d'un écran dédié présentant la carte héros du solde, le budget mensuel paramétré et le récapitulatif des flux.
  - Journal complet de toutes les opérations concernant le compte (crédits, débits, ventilations, virements partenaires).
  - Affichage comptable orienté compte : montant préfixé d'un `+` en vert émeraude pour les entrées, ou d'un `−` en rouge pour les sorties.
- **Graphique mensuel interactif des flux (`fl_chart`)** :
  - Visualisation comparative par mois sous forme d'histogramme double barre (Entrées en vert vs Sorties en rouge) sur les 6 derniers mois.
  - Infobulle interactive au toucher révélant le libellé complet du mois et les montants exacts en FCFA.
  - Filtrage instantané : touchez une barre mensuelle pour filtrer immédiatement la liste des opérations du mois choisi, avec bouton de réinitialisation rapide.
- **Synthèse financière par compte** :
  - Indicateurs clés en en-tête : Total des entrées cumulées et Total des sorties cumulées.

---

## [1.1.3] - 2026-09-25

### Corrigé & Amélioré
- **Règle d'or financière des Enveloppes Budgétaires (Allocation Nette)** :
  - Résolution de l'incohérence entre les jauges d'enveloppes du Dashboard et les soldes réels de l'onglet Comptes.
  - Tout virement interne ou cotisation sortant d'une enveloppe est désormais automatiquement déduit de son allocation nette (`allocated`), conformément aux normes comptables et à la méthode Zero-Based Budgeting (YNAB).
  - Élimination absolue du risque de double comptage : un virement interne sortant vers un compte personnel n'est plus artificiellement confondu avec une dépense.
  - Préservation de la parité comptable au franc près : `Solde = Alloué net − Consommé`.
- **Fiabilisation des données de démonstration (`seedDemo`)** :
  - Ajustement des montants de cotisations dans le scénario de test pour éliminer l'exception de solde insuffisant lors de l'exploration de la démo.
- **Documentation d'audit financier** :
  - Ajout du document technique et financier de référence [`docs/ANALYSE_COHERENCE_ENVELOPPES.md`](docs/ANALYSE_COHERENCE_ENVELOPPES.md).

---

## [1.1.2] - 2026-09-22

### Corrigé
- **Exportation et Importation des sauvegardes JSON (.json)** :
  - L'exportation de la sauvegarde génère désormais un vrai fichier physique `.json` (`application/json`) horodaté (`smartfin_backup_YYYYMMDD_HHmm.json`), évitant ainsi que le fichier partagé soit interprété ou enregistré au format `.txt` par Android ou les applications de stockage.
  - Le sélecteur de fichier pour l'importation (`Onboarding` et `Paramètres`) cible nativement les fichiers `.json` tout en acceptant les fichiers `.txt` de sauvegardes antérieures par rétrocompatibilité.
  - Nettoyage et suppression automatique de la marque d'ordre des octets UTF-8 (BOM `\uFEFF`) lors de l'importation pour éliminer les erreurs de décodage.
  - L'exportation de l'historique CSV génère également un vrai fichier physique `.csv` (`text/csv`) horodaté.
- **Cycle de vie des contrôleurs de formulaires modaux** :
  - Résolution de l'exception Flutter `A TextEditingController was used after being disposed` lors de la fermeture des feuilles modales (`showModalBottomSheet`) grâce à l'encapsulation dans des `StatefulWidget` dédiés.

---

## [1.1.1] - 2026-09-22

### Ajouté
- **Modification des projets d'achat (coût cible / prix)** :
  - Possibilité de modifier le coût cible d'un projet d'achat (par exemple si le prix en magasin a augmenté ou baissé depuis la planification).
  - Possibilité de modifier le libellé de l'achat avec synchronisation automatique du nom du compte cagnotte (`Cagnotte — <titre>`).
  - Possibilité d'ajuster ou d'effacer la date d'échéance souhaitée.
  - Recalcul dynamique et immédiat de la progression et du solde restant à cotiser.
  - Ajout d'un bouton direct « Modifier » sur les cartes d'achats actifs et d'un menu d'options `⋮`.
  - Possibilité de supprimer proprement un projet d'achat lorsque sa cagnotte est vide (0 FCFA cotisé).
- **Modification du montant des dépenses** :
  - Possibilité d'ajuster le montant dépensé directement depuis la feuille de détail d'une opération (`showTxDetails`).
  - Prise en charge du mode édition dans le formulaire de dépense (`ExpenseView`) avec verrouillage des autres champs (libellé, compte, catégorie, date) pour préserver l'intégrité de l'opération.
  - Ajustement automatique et transparent du solde du compte payeur :
    - Si le montant augmente : vérification du solde suffisant et débit du complément.
    - Si le montant diminue : recrédit immédiat de la différence sur le compte payeur.
  - Piste d'audit automatique traçant l'ancien et le nouveau montant.
- **Modification du montant des encaissements et virements** :
  - **Encaissements** : modification du montant encaissé avec réajustement direct du solde du compte bénéficiaire (crédit si hausse, débit avec contrôle de solde suffisant si baisse). Formulaire d'édition (`IncomeView`) et bottom sheet directe (`showEditTransactionAmountSheet`).
  - **Virements internes** : modification du montant transféré avec rééquilibrage automatisé des deux comptes concernés (débit de la source et crédit du destinataire si hausse ; rétrocession inverse avec contrôle de solde si baisse). Formulaire d'édition (`TransferView`) et bottom sheet directe.
  - Intégration unifiée dans la consultation de transactions et contrôle d'invariants comptables.
- **Journal des modifications intégré dans l'application** :
  - Consultation des nouveautés et correctifs de toutes les versions depuis l'écran des Paramètres.
  - Constante centralisée `kAppVersion` (`1.1.1`) et structure de données `kChangelog`.

---

## [1.1.0] - 2026-09-21

### Ajouté
- **Système complet de Sauvegarde & Restauration (JSON v1.1.0)** :
  - Restauration de sauvegarde dès l'écran de premier démarrage (Onboarding) pour réinstaller facilement ses données sur un nouvel appareil.
  - Exportation complète de la base de données au format JSON structuré depuis les Paramètres avec partage natif.
  - Importation via sélection de fichier `.json` natif ou via zone de copier-coller pour une compatibilité universelle.
  - Préservation intégrale de la piste d'audit (`auditTrail`) et recalcul automatique des soldes et statistiques.
- **Identité SmartFin** :
  - Renommage et harmonisation de l'application sous le nom officiel SmartFin à travers Android, le Web et les interfaces utilisateur.

---

## [1.0.1] - 2026-09-20

### Corrigé
- Correction des débordements d'affichage visuels (RenderFlex overflow) sur les écrans d'accueil (Splash et Onboarding).
- Unification du bouton d'action flottant (FAB) dans `ShellView` pour éliminer les collisions d'animations Hero.
- Amélioration de la lisibilité des badges d'échéance et des statuts des cagnottes.

---

## [1.0.0] - 2026-09-19

### Ajouté
- **Lancement initial de SamaFi Mobile** (application Flutter de gestion financière personnelle, devise FCFA, 100% hors-ligne) :
  - **Architecture multi-comptes** : Caisses (portefeuilles), Charges fixes, Épargne, Enveloppes budgétaires, Projets (cagnottes), Fonds tiers (fiducie), Tontines.
  - **Encaissements ventilés** : obligation stricte de répartir tout revenu sur un ou plusieurs comptes cibles.
  - **Dettes et Emprunts** : séparation rigoureuse des flux de passif et de consommation, suivi des créances et remboursements.
  - **Fonds tiers (Fiducie)** : étanchéité de l'argent confié par un tiers, détection automatique des détournements d'usage et reversements.
  - **Tontines rotatives** : suivi des cycles, cotisations et attribution des cagnottes.
  - **Achats planifiés** : constitution progressive de cagnottes dédiées avec renoncement tracé (redirection vers l'épargne sans perte de fonds).
  - **Tableau de bord financier** : solde disponible total, patrimoine net, camembert des dépenses par catégorie, barres de flux sur 30 jours et suivi des enveloppes.
  - **Journal d'audit et Historique** : historique complet filtrable, recherche textuelle et export au format CSV.
