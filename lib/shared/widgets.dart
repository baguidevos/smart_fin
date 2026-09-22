/// SamaFi — widgets partagés : cartes de statistiques, tuiles d'opérations,
/// sélecteur de compte en bottom sheet, champs (montant FCFA, date), chips
/// de choix, dialogs de confirmation et snackbars.
///
/// Convention : les vues métier s'appuient uniquement sur ce kit + thème,
/// jamais sur des styles ad hoc, pour garder une cohérence visuelle totale.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../data/repository.dart';

// ---------------------------------------------------------------------------
// Cartes & en-têtes
// ---------------------------------------------------------------------------

/// Carte de statistique compacte (libellé + valeur + icône).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = color ?? cs.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tint.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: tint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête de section avec action optionnelle (« Tout voir », « Ajouter »…).
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: cs.primary,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// État vide réutilisable (aucune donnée).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: cs.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barre de progression arrondie (0 → 1).
class ProgressTrack extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const ProgressTrack({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value.clamp(0.0, 1.0);
    final c = color ?? cs.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: c.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(c),
        ),
      ),
    );
  }
}

/// Puce de rôle de compte (couleur + libellé du rôle).
class RoleChip extends StatelessWidget {
  final AccountRole role;

  const RoleChip({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final c = role.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tuile d'opération + détail (piste d'audit)
// ---------------------------------------------------------------------------

/// Ligne d'opération : icône typée, libellé, date, compte, montant signé.
/// Un appui ouvre le détail complet avec la piste d'audit horodatée.
class TxTile extends StatelessWidget {
  final Transaction tx;

  const TxTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final repo = Get.find<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;
    final isCredit = tx.type.isCredit;
    final isNeutral = tx.type.isNeutral;
    final amountColor = isCredit
        ? Colors.green.shade700
        : isNeutral
            ? cs.onSurfaceVariant
            : Colors.red.shade700;
    final account =
        repo.accountName(tx.fromAccountId ?? tx.accountId) ?? '';
    final to = repo.accountName(tx.toAccountId);
    final subtitle = StringBuffer(dateMedium(tx.date));
    if (account.isNotEmpty) subtitle.write(' · $account');
    if (to != null && to.isNotEmpty && to != account) {
      subtitle.write(' → $to');
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: (tx.type.isDebtFlow
                ? Colors.orange.shade700
                : cs.primary)
            .withOpacity(0.12),
        child: Icon(
          tx.type.icon,
          size: 19,
          color: tx.type.isDebtFlow ? Colors.orange.shade700 : cs.primary,
        ),
      ),
      title: Text(
        tx.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${tx.type.label} · $subtitle',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
      trailing: Text(
        fcfaSigned(isCredit || isNeutral ? tx.amount : -tx.amount),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          color: amountColor,
        ),
      ),
      onTap: () => showTxDetails(context, tx),
    );
  }
}

/// Bottom sheet : détail complet d'une opération, piste d'audit incluse.
Future<void> showTxDetails(BuildContext context, Transaction tx) {
  final repo = Get.find<FinanceRepository>();
  final cs = Theme.of(context).colorScheme;
  String? row(String label, String value) => value.isEmpty ? null : '$label : $value';
  final lines = <String?>[
    'Type : ${tx.type.label}',
    row('Montant', fcfa(tx.amount)),
    row('Date', dateFull(tx.date)),
    row('Catégorie', tx.category ?? ''),
    row(
        'Compte',
        repo.accountName(tx.fromAccountId ?? tx.accountId) ?? ''),
    row('Vers', repo.accountName(tx.toAccountId) ?? ''),
    null,
    tx.auditTrail,
  ].whereType<String>().toList();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(tx.type.icon, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tx.label,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  fcfa(tx.amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tx.type.isCredit
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: l.startsWith('Type') || l.startsWith('Montant')
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                    fontWeight: l.startsWith('Type') || l.startsWith('Montant')
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (tx.type == TxType.expense ||
                tx.type == TxType.income ||
                tx.type == TxType.transfer) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showEditTransactionAmountSheet(context, tx);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier le montant'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet universelle permettant de modifier le montant d'une opération
/// enregistrée (dépense, encaissement ou virement interne).
Future<void> showEditTransactionAmountSheet(
    BuildContext context, Transaction tx) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _EditTransactionAmountSheet(tx: tx),
  );
}

class _EditTransactionAmountSheet extends StatefulWidget {
  final Transaction tx;

  const _EditTransactionAmountSheet({required this.tx});

  @override
  State<_EditTransactionAmountSheet> createState() =>
      _EditTransactionAmountSheetState();
}

class _EditTransactionAmountSheetState
    extends State<_EditTransactionAmountSheet> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.tx.amount.toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final repo = Get.find<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;

    String title;
    String amountLabel;
    String accountInfo = '';
    Color iconColor = cs.primary;

    switch (tx.type) {
      case TxType.expense:
        title = 'Modifier le montant de la dépense';
        amountLabel = 'Nouveau montant dépensé';
        iconColor = Colors.red.shade700;
        final account = repo.accountById(tx.fromAccountId ?? tx.accountId);
        if (account != null) {
          accountInfo =
              'Compte payeur : ${account.name} · Solde : ${fcfa(account.balance)}';
        }
        break;
      case TxType.income:
        title = "Modifier le montant de l'encaissement";
        amountLabel = 'Nouveau montant encaissé';
        iconColor = Colors.green.shade700;
        final account = repo.accountById(tx.toAccountId ?? tx.accountId);
        if (account != null) {
          accountInfo =
              'Compte bénéficiaire : ${account.name} · Solde : ${fcfa(account.balance)}';
        }
        break;
      case TxType.transfer:
        title = 'Modifier le montant du virement';
        amountLabel = 'Nouveau montant transféré';
        iconColor = cs.primary;
        final from = repo.accountById(tx.fromAccountId ?? tx.accountId);
        final to = repo.accountById(tx.toAccountId);
        if (from != null && to != null) {
          accountInfo =
              'De « ${from.name} » (${fcfa(from.balance)}) → Vers « ${to.name} » (${fcfa(to.balance)})';
        }
        break;
      default:
        title = "Modifier le montant de l'opération";
        amountLabel = 'Nouveau montant';
        break;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_outlined, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Opération : « ${tx.label} »',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (accountInfo.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  accountInfo,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AmountField(
                controller: _amountCtrl,
                label: amountLabel,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final newAmount = parseAmount(_amountCtrl.text) ?? 0;
                    if (newAmount <= 0) {
                      errorSnack(AppException(
                          'Le montant doit être supérieur à 0 FCFA.'));
                      return;
                    }
                    if (newAmount == tx.amount) {
                      Navigator.of(context).pop();
                      return;
                    }
                    try {
                      repo.updateTransactionAmount(
                        transactionId: tx.id,
                        newAmount: newAmount,
                      );
                      Navigator.of(context).pop();
                      successSnack(
                        'Montant modifié',
                        '« ${tx.label} » : ${fcfa(newAmount)}',
                      );
                    } catch (e) {
                      errorSnack(e);
                    }
                  },
                  icon: const Icon(Icons.check, size: 19),
                  label: const Text('Enregistrer le nouveau montant'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rétrocompatibilité : redirige vers [showEditTransactionAmountSheet].
Future<void> showEditExpenseAmountSheet(BuildContext context, Transaction tx) =>
    showEditTransactionAmountSheet(context, tx);

// ---------------------------------------------------------------------------
// Sélecteur de compte (bottom sheet)
// ---------------------------------------------------------------------------

/// Sélection d'un compte dans une liste filtrée. Retourne le compte choisi
/// ou null (annulé).
Future<Account?> showAccountPicker(
  BuildContext context, {
  required List<Account> accounts,
  String? selectedId,
  String title = 'Choisir un compte',
  bool showBalance = true,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text('Aucun compte disponible.'),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: accounts.length,
                itemBuilder: (context, i) {
                  final a = accounts[i];
                  final selected = a.id == selectedId;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: a.role.color.withOpacity(0.13),
                      child: Icon(a.role.icon, size: 19, color: a.role.color),
                    ),
                    title: Text(
                      a.name,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: showBalance
                        ? Text(
                            '${a.role.label} · ${fcfa(a.balance)}',
                            style: const TextStyle(fontSize: 12),
                          )
                        : Text(a.role.label,
                            style: const TextStyle(fontSize: 12)),
                    trailing: selected
                        ? Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => Get.back(result: a),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Confirmation & snackbars
// ---------------------------------------------------------------------------

/// Dialog de confirmation. Retourne true si l'utilisateur confirme.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: cs.errorContainer,
                  foregroundColor: cs.onErrorContainer,
                )
              : null,
          onPressed: () => Get.back(result: true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Erreur métier → snackbar rouge, message français prêt à l'emploi.
void errorSnack(Object error) {
  final message = error is AppException
      ? error.message
      : (error is String ? error : "Une erreur inattendue est survenue.");
  final context = Get.context ?? Get.overlayContext;
  if (context == null) return;
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: cs.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attention',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onErrorContainer,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      color: cs.onErrorContainer.withOpacity(0.92),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 3500),
      ),
    );
}

/// Confirmation de réussite → snackbar vert.
void successSnack(String title, [String? message]) {
  final context = Get.context ?? Get.overlayContext;
  if (context == null) return;
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: cs.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(Icons.check_circle, color: cs.onPrimaryContainer, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                      fontSize: 14,
                    ),
                  ),
                  if (message != null && message.isNotEmpty)
                    Text(
                      message,
                      style: TextStyle(
                        color: cs.onPrimaryContainer.withOpacity(0.92),
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 2800),
      ),
    );
}

// ---------------------------------------------------------------------------
// Champs de formulaire
// ---------------------------------------------------------------------------

/// Libellé + champ (espacement constant des formulaires).
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;

  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

/// Champ de montant FCFA : clavier numérique, chiffres uniquement.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      hint: hint,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        maxLength: 12,
        decoration: const InputDecoration(
          hintText: '0',
          suffixText: 'FCFA',
          counterText: '',
        ),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Champ date : lecture seule + sélecteur Material en français.
class DateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final bool allowEmpty;

  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.allowEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            locale: const Locale('fr', 'FR'),
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            suffixIcon: value != null && allowEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onChanged(null),
                  )
                : const Icon(Icons.calendar_month_outlined, size: 20),
          ),
          child: Text(
            value != null ? dateFull(value!) : 'Non définie',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: value != null
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Série de chips à choix unique (rôles, catégories, fréquences…).
class ChipChoice<T> extends StatelessWidget {
  final List<T> options;
  final String Function(T) labelOf;
  final T? value;
  final ValueChanged<T> onChanged;

  const ChipChoice({
    super.key,
    required this.options,
    required this.labelOf,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelOf(o)),
            selected: o == value,
            onSelected: (_) => onChanged(o),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: o == value ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Squelette de formulaire plein écran (AppBar + corps défilant + bouton)
// ---------------------------------------------------------------------------

/// Gabarit commun des formulaires : AppBar retour, validation, bouton d'action
/// en bas, champs dans une carte unique.
class FormScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback onSubmit;
  final IconData submitIcon;
  final List<Widget>? actions;

  const FormScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.submitIcon = Icons.check,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: Form(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: onSubmit,
            icon: Icon(submitIcon, size: 19),
            label: Text(submitLabel),
          ),
        ),
      ),
    );
  }
}
