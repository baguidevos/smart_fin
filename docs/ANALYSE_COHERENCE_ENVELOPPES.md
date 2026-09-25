# Analyse Financière & Règle d'Or : Cohérence des Enveloppes Budgétaires (SmartFin v1.1.3)

---

## 1. Contexte & Problématique Observée

Sur l'écran d'accueil (**Dashboard**) et dans l'onglet **Comptes**, un décalage apparent a été constaté lors du suivi d'une enveloppe budgétaire (*ex. compte « Imprévus »*) :

* **Affichage Onglet Comptes :**
  * Solde réel disponible : **3 000 FCFA**
* **Affichage Dashboard (Section Enveloppes) :**
  * **2 000 FCFA consommés / 15 000 FCFA alloués (13 % consommé)**
  * Ce qui induisait visuellement un reste théorique de $15\,000 - 2\,000 = \mathbf{13\,000\text{ FCFA}}$, créant une incompréhension face aux **3 000 FCFA** affichés sur le compte.

---

## 2. Reconstitution Comptable Réelle

L'audit des flux de trésorerie sur le compte révèle la chaîne d'opérations suivante :

1. **21 septembre — Dotation initiale de l'enveloppe :**
   * Virement entrant : $\mathbf{+15\,000\text{ FCFA}}$ (*Caisse Principale → Imprévus*).
   * Solde comptable : $15\,000\text{ FCFA}$.
2. **23 septembre — Réallocation budgétaire interne :**
   * Virement sortant : $\mathbf{-10\,000\text{ FCFA}}$ (*Imprévus → Dépenses personnelles* pour couvrir une urgence médicale).
   * Solde comptable : $15\,000 - 10\,000 = 5\,000\text{ FCFA}$.
3. **24 septembre — Dépense de consommation directe :**
   * Dépense directe : $\mathbf{-2\,000\text{ FCFA}}$ (*Admission hôpital*).
   * Solde comptable final : $5\,000 - 2\,000 = \mathbf{3\,000\text{ FCFA}}$.

---

## 3. Origine du Biais dans la Formule Antérieure

Dans les versions $\le 1.1.2$, la fonction `envelopeStats30j()` calculait les indicateurs ainsi :

```dart
// Code antérieur (v1.1.2) :
if (t.toAccountId == e.id && t.type != TxType.debtIn) {
  allocated += t.amount; // Compte les 15 000 FCFA entrants
}
if (t.type == TxType.expense && t.fromAccountId == e.id) {
  consumed += t.amount;  // Compte UNIQUEMENT les 2 000 FCFA de dépense
}
// Le virement sortant de 10 000 FCFA n'était NI déduit de 'allocated', NI ajouté à 'consumed'.
```

**Biais induit :** Les virements sortants diminuaient bien le solde réel du compte, mais étaient ignorés par la jauge d'allocation, affichant une enveloppe artificiellement surévaluée.

---

## 4. Évaluation des Deux Options Théoriques

### Option A : Assimiler le virement sortant à une « Consommation »
$$\text{Consommé} = \text{Dépenses directes} + \text{Virements sortants}$$

❌ **Rejetée pour hérésie financière :**
1. **Risque de double comptage :** Si les $10\,000\text{ FCFA}$ virés vers le compte personnel font l'objet d'une dépense ultérieure (ex. clinique payée par le compte personnel), la même somme est comptabilisée deux fois comme consommation.
2. **Effet pervers sur l'épargne du reliquat :** Si en fin de mois l'utilisateur verse le reliquat d'une enveloppe vers son compte Épargne, ce virement serait affiché comme une dépense à 100 %, punissant l'épargne au lieu de la valoriser.
3. **Non-respect des normes comptables :** Un virement interne de trésorerie entre deux comptes d'actif est une opération blanche, sans impact sur le compte de résultat.

---

### Option B : La Règle d'Or — L'Allocation Nette (Réallocation Budgétaire)
$$\text{Allocation Nette} = \text{Entrées sur l'enveloppe} - \text{Virements & cotisations sortants}$$
$$\text{Consommation} = \text{Dépenses directes réelles}$$

✅ **Adoptée comme Règle d'Or (Conforme aux standards YNAB & Comptabilité Analytique) :**
1. **Séparation étanche :** Préserve la distinction entre flux de trésorerie interne et charges d'exploitation.
2. **Formule mathématique infaillible :**
   $$\text{Solde restant} = \text{Allocation Nette} - \text{Consommation}$$
   $$3\,000\text{ FCFA} = (15\,000 - 10\,000) - 2\,000 = 5\,000 - 2\,000 = \mathbf{3\,000\text{ FCFA}}$$
3. **Clarté pour l'utilisateur :**
   * Dashboard : **2 000 FCFA / 5 000 FCFA (40 % consommé)**.
   * Reste de l'enveloppe : **3 000 FCFA (60 % disponible)**.
   * Onglet Comptes : **Solde 3 000 FCFA**.
   * 👉 **Concordance parfaite au centime près.**

---

## 5. Mise en Œuvre Technique (v1.1.3)

Dans [`lib/data/repository.dart`](../lib/data/repository.dart), la méthode `envelopeStats30j()` est mise à jour :

```dart
List<({Account account, int allocated, int consumed})> envelopeStats30j() {
  final since = _since30d;
  return activeAccounts
      .where((a) => a.role == AccountRole.envelope)
      .map((e) {
    var allocated = 0;
    var consumed = 0;
    for (final t in transactions) {
      if (t.date.isBefore(since)) continue;
      // Entrées sur l'enveloppe (ventilations, dotations)
      if (t.toAccountId == e.id && t.type != TxType.debtIn) {
        allocated += t.amount;
      }
      // Règle d'or : réallocations / désallocations (virements ou cotisations sortants)
      if (t.fromAccountId == e.id &&
          (t.type == TxType.transfer || t.type == TxType.contribution)) {
        allocated -= t.amount;
      }
      // Dépenses de consommation effectives
      if (t.type == TxType.expense && t.fromAccountId == e.id) {
        consumed += t.amount;
      }
    }
    final netAllocated = allocated > 0 ? allocated : 0;
    return (account: e, allocated: netAllocated, consumed: consumed);
  }).toList()
    ..sort((a, b) => b.consumed.compareTo(a.consumed));
}
```

---

## 6. Bonne Pratique Conseillée à l'Utilisateur

Pour les dépenses imprévues de santé ou du quotidien :
* **Pratique recommandée :** Enregistrer la dépense **directement sur le compte « Imprévus »**.
* **Avantage :** Évite les virements intermédiaires vers le compte personnel, garantit la bonne catégorisation statistique dès l'origine, et maintient l'historique limpide.
