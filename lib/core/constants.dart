/// SamaFi — constantes du domaine : rôles de comptes, types d'opérations,
/// catégories de dépenses (libellés français + icônes + couleurs).
library;

import 'package:flutter/material.dart';

import '../data/models.dart';
import 'format.dart';

/// Libellés français des rôles de compte (vocabulaire du cahier des charges).
const Map<AccountRole, String> kRoleLabels = {
  AccountRole.wallet: 'Caisse',
  AccountRole.budget: 'Charges fixes',
  AccountRole.savings: 'Épargne',
  AccountRole.envelope: 'Enveloppe',
  AccountRole.project: 'Projet',
  AccountRole.fiduciaire: 'Fiducie',
  AccountRole.tontine: 'Tontine',
};

/// Descriptions courtes affichées sous les libellés.
const Map<AccountRole, String> kRoleHints = {
  AccountRole.wallet: 'Argent immédiatement disponible',
  AccountRole.budget: 'Charges récurrentes du mois',
  AccountRole.savings: 'Épargne de précaution',
  AccountRole.envelope: 'Enveloppe budgétaire mensuelle',
  AccountRole.project: 'Cagnotte vers un objectif',
  AccountRole.fiduciaire: 'Argent confié par un tiers',
  AccountRole.tontine: 'Mes cotisations en cours',
};

/// Couleurs par rôle (mêmes germes que la version web SamaFi).
const Map<AccountRole, String> kRoleColors = {
  AccountRole.wallet: '#059669', // émeraude
  AccountRole.budget: '#d97706', // ambre
  AccountRole.savings: '#0f766e', // sarcelle foncée
  AccountRole.envelope: '#ca8a04', // jaune foncé
  AccountRole.project: '#7c3aed', // violet
  AccountRole.fiduciaire: '#c2410c', // orange foncé
  AccountRole.tontine: '#4d7c0f', // vert olive
};

/// Icônes Material par rôle.
const Map<AccountRole, IconData> kRoleIcons = {
  AccountRole.wallet: Icons.account_balance_wallet_outlined,
  AccountRole.budget: Icons.receipt_long_outlined,
  AccountRole.savings: Icons.savings_outlined,
  AccountRole.envelope: Icons.mail_outline,
  AccountRole.project: Icons.flag_outlined,
  AccountRole.fiduciaire: Icons.volunteer_activism_outlined,
  AccountRole.tontine: Icons.groups_outlined,
};

/// Libellés français des types d'opération.
const Map<TxType, String> kTxTypeLabels = {
  TxType.income: 'Encaissement',
  TxType.expense: 'Dépense',
  TxType.transfer: 'Virement',
  TxType.contribution: 'Cotisation',
  TxType.purchasePaid: 'Achat payé',
  TxType.redirection: 'Redirection',
  TxType.tpIn: 'Fonds reçu',
  TxType.tpSpend: 'Dépense fiducie',
  TxType.tpDivert: 'Détournement',
  TxType.tpReimburse: 'Reversement fiducie',
  TxType.tontineOut: 'Cotisation tontine',
  TxType.tontineIn: 'Tour de tontine reçu',
  TxType.debtIn: 'Emprunt',
  TxType.debtRepay: 'Remboursement',
};

/// Icônes Material par type d'opération.
const Map<TxType, IconData> kTxTypeIcons = {
  TxType.income: Icons.south_west,
  TxType.expense: Icons.north_east,
  TxType.transfer: Icons.swap_horiz,
  TxType.contribution: Icons.savings_outlined,
  TxType.purchasePaid: Icons.shopping_bag_outlined,
  TxType.redirection: Icons.alt_route_outlined,
  TxType.tpIn: Icons.volunteer_activism_outlined,
  TxType.tpSpend: Icons.receipt_long_outlined,
  TxType.tpDivert: Icons.redo,
  TxType.tpReimburse: Icons.undo,
  TxType.tontineOut: Icons.groups_outlined,
  TxType.tontineIn: Icons.emoji_events_outlined,
  TxType.debtIn: Icons.account_balance_outlined,
  TxType.debtRepay: Icons.payments_outlined,
};

/// Une catégorie de dépense usuelle (utilisée pour le camembert du tableau
/// de bord et le formulaire de dépense).
class ExpenseCategory {
  final String label;
  final IconData icon;
  const ExpenseCategory(this.label, this.icon);
}

const List<ExpenseCategory> kExpenseCategories = [
  ExpenseCategory('Alimentation', Icons.shopping_basket_outlined),
  ExpenseCategory('Transport', Icons.directions_bus_outlined),
  ExpenseCategory('Logement', Icons.home_outlined),
  ExpenseCategory('Factures', Icons.receipt_outlined),
  ExpenseCategory('Santé', Icons.medical_services_outlined),
  ExpenseCategory('Éducation', Icons.school_outlined),
  ExpenseCategory('Loisirs', Icons.celebration_outlined),
  ExpenseCategory('Habillement', Icons.checkroom_outlined),
  ExpenseCategory('Communication', Icons.phone_android_outlined),
  ExpenseCategory('Imprévus', Icons.bolt_outlined),
  ExpenseCategory('Autre', Icons.more_horiz),
];

/// Icône d'une catégorie à partir de son libellé (repli : « Autre »).
IconData categoryIcon(String? label) {
  for (final c in kExpenseCategories) {
    if (c.label == label) return c.icon;
  }
  return Icons.more_horiz;
}

/// Extensions pratiques sur les enums du domaine.
extension AccountRoleX on AccountRole {
  String get label => kRoleLabels[this]!;
  String get hint => kRoleHints[this]!;
  String get colorHex => kRoleColors[this]!;
  Color get color => hexColor(kRoleColors[this]!);
  IconData get icon => kRoleIcons[this]!;

  /// Seuls les comptes « charges fixes » et « enveloppes » ont un budget
  /// mensuel suivi (carte « Budgets du mois » côté web).
  bool get isBudgetable =>
      this == AccountRole.budget || this == AccountRole.envelope;
}

extension TxTypeX on TxType {
  String get label => kTxTypeLabels[this]!;
  IconData get icon => kTxTypeIcons[this]!;

  /// Opérations qui font entrer de l'argent sur un compte (montant en vert).
  bool get isCredit =>
      this == TxType.income ||
      this == TxType.tpIn ||
      this == TxType.debtIn ||
      this == TxType.tontineIn ||
      this == TxType.tpReimburse;

  /// Virements et mouvements internes (montant neutre).
  bool get isNeutral =>
      this == TxType.transfer ||
      this == TxType.contribution ||
      this == TxType.tpDivert ||
      this == TxType.redirection;

  /// L'emprunt est un passif, pas un revenu ; son remboursement n'est pas une
  /// dépense de consommation (§ dettes explicites — cahier des charges).
  bool get isDebtFlow => this == TxType.debtIn || this == TxType.debtRepay;
}

/// Version actuelle de l'application.
const String kAppVersion = '1.1.3';

/// Entrée du journal des versions (changelog).
class ChangelogEntry {
  final String version;
  final String date;
  final String title;
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.title,
    required this.changes,
  });
}

/// Historique complet des versions et nouveautés de l'application.
const List<ChangelogEntry> kChangelog = [
  ChangelogEntry(
    version: '1.1.3',
    date: '25 septembre 2026',
    title: 'Règle d\'or financière des enveloppes & Cohérence Dashboard / Comptes',
    changes: [
      'Enveloppes budgétaires : adoption de la règle d\'or de l\'allocation nette déduisant automatiquement les virements internes et réallocations sortants.',
      'Élimination du risque de double comptage entre virements internes et dépenses réelles de consommation.',
      'Cohérence comptable parfaite : adéquation exacte au franc près entre les jauges d\'enveloppes du Dashboard et les soldes réels de l\'onglet Comptes.',
      'Fiabilisation du scénario de démonstration et protection contre les dépassements d\'épargne.',
    ],
  ),
  ChangelogEntry(
    version: '1.1.2',
    date: '22 septembre 2026',
    title: 'Export/Import natif JSON (.json) & Stabilité des fenêtres modales',
    changes: [
      'Sauvegardes : exportation directe sous forme de fichier réel .json (MIME application/json) pour éliminer le format .txt imposé par certains gestionnaires.',
      'Restauration : sélecteur de fichier optimisé pour .json avec compatibilité de secours pour les fichiers .txt existants.',
      'Résilience JSON : prise en charge automatique des fichiers avec marque d\'ordre des octets (BOM UTF-8).',
      'Historique CSV : exportation sous forme de vrai fichier .csv avec nommage horodaté.',
      'Correctif critique : élimination de l\'erreur "TextEditingController was used after being disposed" lors de la fermeture des fenêtres modales.',
    ],
  ),
  ChangelogEntry(
    version: '1.1.1',
    date: '22 septembre 2026',
    title: "Ajustement des projets d'achat & modification des opérations (dépenses, encaissements, virements)",
    changes: [
      "Projets d'achat : modification possible du coût cible (prix) si le prix réel a évolué, du titre et de la date d'échéance.",
      "Projets d'achat : synchronisation automatique du nom du compte cagnotte dédié et recalcul réactif de la progression.",
      "Projets d'achat : option de suppression propre lorsqu'aucune cotisation n'a encore été engagée.",
      "Dépenses : correction du montant dépensé avec réajustement automatique du compte payeur.",
      "Encaissements : modification du montant encaissé avec réajustement immédiat du solde du compte bénéficiaire.",
      "Virements internes : modification du montant transféré avec rééquilibrage automatique des comptes source et destination.",
      "Piste d'audit et contrôles de solde : traçabilité complète de l'historique et protection stricte contre les soldes négatifs.",
      "Journal des modifications : intégration du changelog complet accessible depuis les paramètres.",
    ],
  ),
  ChangelogEntry(
    version: '1.1.0',
    date: '21 septembre 2026',
    title: 'Sauvegardes complètes & Identité SmartFin',
    changes: [
      'Exportation et importation complètes des données au format JSON (v1.1.0).',
      "Restauration de sauvegarde dès l'onboarding (premier démarrage) ou à tout moment dans les Paramètres.",
      'Sélecteur de fichier .json natif et zone de collage manuel pour une flexibilité maximale.',
      'Renommage et harmonisation complète sous le nom officiel SmartFin.',
      "Préservation de l'audit trail complet et intégrité comptable lors de l'importation.",
    ],
  ),
  ChangelogEntry(
    version: '1.0.1',
    date: '20 septembre 2026',
    title: 'Correctifs graphiques & Expérience utilisateur',
    changes: [
      "Résolution des débordements d'affichage (overflow) sur les écrans d'accueil (Splash et Onboarding).",
      "Unification du bouton d'action flottant (FAB) dans ShellView pour éliminer les conflits d'animations.",
      "Amélioration de la lisibilité des badges et puces d'échéance.",
    ],
  ),
  ChangelogEntry(
    version: '1.0.0',
    date: '19 septembre 2026',
    title: 'Lancement initial de SamaFi Mobile',
    changes: [
      'Application de gestion financière personnelle en FCFA fonctionnant 100% hors-ligne.',
      'Gestion multi-comptes : Caisse, Charges fixes, Épargne, Enveloppes, Projets, Fiducie et Tontines.',
      'Ventilation stricte des encaissements sur plusieurs comptes.',
      'Gestion des dettes et emprunts avec traçabilité intégrale des remboursements.',
      'Étanchéité des fonds tiers (fiducie) avec détection des détournements et reversements.',
      'Gestion des cycles et cotisations de tontines.',
      "Achats planifiés avec constitution de cagnottes et redirection sécurisée en cas de renoncement.",
      'Tableau de bord financier dynamique avec graphiques et synthèse mensuelle.',
      'Historique complet des mouvements avec recherche, filtres et export CSV.',
    ],
  ),
];
