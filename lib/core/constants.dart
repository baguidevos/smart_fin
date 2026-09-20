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
