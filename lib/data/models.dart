/// SamaFi — modèles du domaine (calqués sur le schéma Prisma de la version
/// web). Tous les montants sont des entiers FCFA (pas de subdivision).
///
/// Sérialisation JSON manuelle pour la persistance GetStorage.
library;

// ---------------------------------------------------------------------------
// Énumérations (persistées en majuscules, comme sur la version web)
// ---------------------------------------------------------------------------

enum AccountRole {
  wallet,
  budget,
  savings,
  envelope,
  project,
  fiduciaire,
  tontine,
}

enum TxType {
  income,
  expense,
  transfer,
  contribution,
  purchasePaid,
  redirection,
  tpIn,
  tpSpend,
  tpDivert,
  tpReimburse,
  tontineOut,
  tontineIn,
  debtIn,
  debtRepay,
}

enum TontineFrequency { daily, weekly, monthly }
enum DebtStatus { active, settled }
enum PurchaseStatus { active, completed, redirected, cancelled }
enum FundStatus { active, settled }

AccountRole roleFromName(String? s) {
  switch (s?.toUpperCase()) {
    case 'WALLET':
      return AccountRole.wallet;
    case 'BUDGET':
      return AccountRole.budget;
    case 'SAVINGS':
      return AccountRole.savings;
    case 'PROJECT':
      return AccountRole.project;
    case 'FIDUCIAIRE':
      return AccountRole.fiduciaire;
    case 'TONTINE':
      return AccountRole.tontine;
    default:
      return AccountRole.envelope;
  }
}

TxType txTypeFromName(String? s) {
  switch (s?.toUpperCase()) {
    case 'INCOME':
      return TxType.income;
    case 'EXPENSE':
      return TxType.expense;
    case 'TRANSFER':
      return TxType.transfer;
    case 'CONTRIBUTION':
      return TxType.contribution;
    case 'PURCHASE_PAID':
      return TxType.purchasePaid;
    case 'REDIRECTION':
      return TxType.redirection;
    case 'TP_IN':
      return TxType.tpIn;
    case 'TP_SPEND':
      return TxType.tpSpend;
    case 'TP_DIVERT':
      return TxType.tpDivert;
    case 'TP_REIMBURSE':
      return TxType.tpReimburse;
    case 'TONTINE_OUT':
      return TxType.tontineOut;
    case 'TONTINE_IN':
      return TxType.tontineIn;
    case 'DEBT_IN':
      return TxType.debtIn;
    default:
      return TxType.debtRepay;
  }
}

TontineFrequency frequencyFromName(String? s) {
  switch (s?.toUpperCase()) {
    case 'DAILY':
      return TontineFrequency.daily;
    case 'MONTHLY':
      return TontineFrequency.monthly;
    default:
      return TontineFrequency.weekly;
  }
}

// ---------------------------------------------------------------------------
// Comptes & opérations
// ---------------------------------------------------------------------------

/// Ligne de ventilation d'un encaissement : montant versé sur un compte.
class Allocation {
  final String accountId;
  final int amount;

  const Allocation({required this.accountId, required this.amount});

  Map<String, dynamic> toJson() => {'accountId': accountId, 'amount': amount};

  factory Allocation.fromJson(Map<String, dynamic> j) => Allocation(
        accountId: j['accountId'] as String,
        amount: (j['amount'] as num).toInt(),
      );
}

class Account {
  final String id;
  final String name;
  final AccountRole role;
  final String? parentId;
  final int balance;
  final int monthlyBudget;
  final String color;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.name,
    required this.role,
    this.parentId,
    this.balance = 0,
    this.monthlyBudget = 0,
    this.color = '#059669',
    this.sortOrder = 0,
    this.isArchived = false,
    required this.createdAt,
  });

  Account copyWith({
    String? name,
    int? balance,
    int? monthlyBudget,
    bool? isArchived,
    String? color,
    int? sortOrder,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        role: role,
        parentId: parentId,
        balance: balance ?? this.balance,
        monthlyBudget: monthlyBudget ?? this.monthlyBudget,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        isArchived: isArchived ?? this.isArchived,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name.toUpperCase(),
        'parentId': parentId,
        'balance': balance,
        'monthlyBudget': monthlyBudget,
        'color': color,
        'sortOrder': sortOrder,
        'isArchived': isArchived,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String,
        role: roleFromName(j['role'] as String?),
        parentId: j['parentId'] as String?,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        monthlyBudget: (j['monthlyBudget'] as num?)?.toInt() ?? 0,
        color: j['color'] as String? ?? '#059669',
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        isArchived: j['isArchived'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Une opération tracée. `auditTrail` porte l'explication horodatée
/// (exigence §3.2/§3.3 du cahier des charges).
class Transaction {
  final String id;
  final TxType type;
  final int amount;
  final String label;
  final String? category;
  final DateTime date;

  /// Compte principal concerné (celui dont le solde bouge « côté utilisateur »).
  final String? accountId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? purchaseId;
  final String? thirdPartyFundId;
  final String? tontineId;
  final String? debtId;
  final String? auditTrail;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.label,
    this.category,
    required this.date,
    this.accountId,
    this.fromAccountId,
    this.toAccountId,
    this.purchaseId,
    this.thirdPartyFundId,
    this.tontineId,
    this.debtId,
    this.auditTrail,
    required this.createdAt,
  });

  Transaction copyWith({
    TxType? type,
    int? amount,
    String? label,
    String? category,
    DateTime? date,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String? purchaseId,
    String? thirdPartyFundId,
    String? tontineId,
    String? debtId,
    String? auditTrail,
  }) =>
      Transaction(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        label: label ?? this.label,
        category: category ?? this.category,
        date: date ?? this.date,
        accountId: accountId ?? this.accountId,
        fromAccountId: fromAccountId ?? this.fromAccountId,
        toAccountId: toAccountId ?? this.toAccountId,
        purchaseId: purchaseId ?? this.purchaseId,
        thirdPartyFundId: thirdPartyFundId ?? this.thirdPartyFundId,
        tontineId: tontineId ?? this.tontineId,
        debtId: debtId ?? this.debtId,
        auditTrail: auditTrail ?? this.auditTrail,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name.toUpperCase(),
        'amount': amount,
        'label': label,
        'category': category,
        'date': date.toIso8601String(),
        'accountId': accountId,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'purchaseId': purchaseId,
        'thirdPartyFundId': thirdPartyFundId,
        'tontineId': tontineId,
        'debtId': debtId,
        'auditTrail': auditTrail,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        type: txTypeFromName(j['type'] as String?),
        amount: (j['amount'] as num).toInt(),
        label: j['label'] as String,
        category: j['category'] as String?,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        accountId: j['accountId'] as String?,
        fromAccountId: j['fromAccountId'] as String?,
        toAccountId: j['toAccountId'] as String?,
        purchaseId: j['purchaseId'] as String?,
        thirdPartyFundId: j['thirdPartyFundId'] as String?,
        tontineId: j['tontineId'] as String?,
        debtId: j['debtId'] as String?,
        auditTrail: j['auditTrail'] as String?,
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Dettes explicites (emprunts + remboursements)
// ---------------------------------------------------------------------------

class Debt {
  final String id;
  final String creditor;
  final String description;
  final int principal;
  final int fees;
  final DateTime? dueDate;
  final DebtStatus status;
  final DateTime? settledAt;
  final DateTime createdAt;

  const Debt({
    required this.id,
    required this.creditor,
    required this.description,
    required this.principal,
    this.fees = 0,
    this.dueDate,
    this.status = DebtStatus.active,
    this.settledAt,
    required this.createdAt,
  });

  Debt copyWith({
    DebtStatus? status,
    DateTime? settledAt,
    int? fees,
    DateTime? dueDate,
  }) =>
      Debt(
        id: id,
        creditor: creditor,
        description: description,
        principal: principal,
        fees: fees ?? this.fees,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        settledAt: settledAt ?? this.settledAt,
        createdAt: createdAt,
      );

  int get totalDue => principal + fees;

  Map<String, dynamic> toJson() => {
        'id': id,
        'creditor': creditor,
        'description': description,
        'principal': principal,
        'fees': fees,
        'dueDate': dueDate?.toIso8601String(),
        'status': status.name.toUpperCase(),
        'settledAt': settledAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: j['id'] as String,
        creditor: j['creditor'] as String,
        description: j['description'] as String,
        principal: (j['principal'] as num).toInt(),
        fees: (j['fees'] as num?)?.toInt() ?? 0,
        dueDate: j['dueDate'] == null
            ? null
            : DateTime.tryParse(j['dueDate'] as String),
        status: (j['status'] as String?)?.toUpperCase() == 'SETTLED'
            ? DebtStatus.settled
            : DebtStatus.active,
        settledAt: j['settledAt'] == null
            ? null
            : DateTime.tryParse(j['settledAt'] as String),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class DebtRepayment {
  final String id;
  final String debtId;
  final int amount;
  final String? note;
  final DateTime date;
  final String? fromAccountId;

  const DebtRepayment({
    required this.id,
    required this.debtId,
    required this.amount,
    this.note,
    required this.date,
    this.fromAccountId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'debtId': debtId,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
        'fromAccountId': fromAccountId,
      };

  factory DebtRepayment.fromJson(Map<String, dynamic> j) => DebtRepayment(
        id: j['id'] as String,
        debtId: j['debtId'] as String,
        amount: (j['amount'] as num).toInt(),
        note: j['note'] as String?,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        fromAccountId: j['fromAccountId'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Tontines
// ---------------------------------------------------------------------------

class TontineMember {
  final String id;
  final String tontineId;
  final String name;
  final int position;
  final bool isMe;
  final bool hasReceived;
  final DateTime? receivedAt;

  const TontineMember({
    required this.id,
    required this.tontineId,
    required this.name,
    required this.position,
    this.isMe = false,
    this.hasReceived = false,
    this.receivedAt,
  });

  TontineMember copyWith({bool? hasReceived, DateTime? receivedAt}) =>
      TontineMember(
        id: id,
        tontineId: tontineId,
        name: name,
        position: position,
        isMe: isMe,
        hasReceived: hasReceived ?? this.hasReceived,
        receivedAt: receivedAt ?? this.receivedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tontineId': tontineId,
        'name': name,
        'position': position,
        'isMe': isMe,
        'hasReceived': hasReceived,
        'receivedAt': receivedAt?.toIso8601String(),
      };

  factory TontineMember.fromJson(Map<String, dynamic> j) => TontineMember(
        id: j['id'] as String,
        tontineId: j['tontineId'] as String,
        name: j['name'] as String,
        position: (j['position'] as num).toInt(),
        isMe: j['isMe'] as bool? ?? false,
        hasReceived: j['hasReceived'] as bool? ?? false,
        receivedAt: j['receivedAt'] == null
            ? null
            : DateTime.tryParse(j['receivedAt'] as String),
      );
}

class Tontine {
  final String id;
  final String name;
  final int contributionAmount;
  final TontineFrequency frequency;
  final FundStatus status;
  final String accountId;
  final int currentRound;
  final int totalRounds;
  final List<TontineMember> members;
  final DateTime createdAt;

  const Tontine({
    required this.id,
    required this.name,
    required this.contributionAmount,
    required this.frequency,
    this.status = FundStatus.active,
    required this.accountId,
    this.currentRound = 0,
    required this.totalRounds,
    required this.members,
    required this.createdAt,
  });

  Tontine copyWith({
    int? currentRound,
    FundStatus? status,
    List<TontineMember>? members,
  }) =>
      Tontine(
        id: id,
        name: name,
        contributionAmount: contributionAmount,
        frequency: frequency,
        status: status ?? this.status,
        accountId: accountId,
        currentRound: currentRound ?? this.currentRound,
        totalRounds: totalRounds,
        members: members ?? this.members,
        createdAt: createdAt,
      );

  /// Membre « Moi » (exactement un par construction).
  TontineMember? get me => members.where((m) => m.isMe).firstOrNull;

  /// Nombre de tours restant avant mon tour (null si déjà reçu).
  int? get nextMyRound {
    final m = me;
    if (m == null || m.hasReceived) return null;
    return m.position - currentRound;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contributionAmount': contributionAmount,
        'frequency': frequency.name.toUpperCase(),
        'status': status.name.toUpperCase(),
        'accountId': accountId,
        'currentRound': currentRound,
        'totalRounds': totalRounds,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Tontine.fromJson(Map<String, dynamic> j) => Tontine(
        id: j['id'] as String,
        name: j['name'] as String,
        contributionAmount: (j['contributionAmount'] as num).toInt(),
        frequency: frequencyFromName(j['frequency'] as String?),
        status: (j['status'] as String?)?.toUpperCase() == 'SETTLED'
            ? FundStatus.settled
            : FundStatus.active,
        accountId: j['accountId'] as String,
        currentRound: (j['currentRound'] as num?)?.toInt() ?? 0,
        totalRounds: (j['totalRounds'] as num?)?.toInt() ?? 0,
        members: (j['members'] as List<dynamic>? ?? [])
            .map((m) => TontineMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Fonds tiers (fiducie)
// ---------------------------------------------------------------------------

class ThirdPartyFund {
  final String id;
  final String title;
  final String owner;
  final int initialAmount;
  final String purpose;
  final DateTime? deadline;
  final FundStatus status;
  final String accountId;
  final int spentOnPurpose;
  final int divertedAmount;
  final int reimbursedAmount;
  final DateTime? closedAt;
  final DateTime createdAt;

  const ThirdPartyFund({
    required this.id,
    required this.title,
    required this.owner,
    required this.initialAmount,
    required this.purpose,
    this.deadline,
    this.status = FundStatus.active,
    required this.accountId,
    this.spentOnPurpose = 0,
    this.divertedAmount = 0,
    this.reimbursedAmount = 0,
    this.closedAt,
    required this.createdAt,
  });

  ThirdPartyFund copyWith({
    int? spentOnPurpose,
    int? divertedAmount,
    int? reimbursedAmount,
    FundStatus? status,
    DateTime? closedAt,
  }) =>
      ThirdPartyFund(
        id: id,
        title: title,
        owner: owner,
        initialAmount: initialAmount,
        purpose: purpose,
        deadline: deadline,
        status: status ?? this.status,
        accountId: accountId,
        spentOnPurpose: spentOnPurpose ?? this.spentOnPurpose,
        divertedAmount: divertedAmount ?? this.divertedAmount,
        reimbursedAmount: reimbursedAmount ?? this.reimbursedAmount,
        closedAt: closedAt ?? this.closedAt,
        createdAt: createdAt,
      );

  /// Créance interne : argent détourné pour un usage personnel non remboursé.
  int get creance => divertedAmount - reimbursedAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'owner': owner,
        'initialAmount': initialAmount,
        'purpose': purpose,
        'deadline': deadline?.toIso8601String(),
        'status': status.name.toUpperCase(),
        'accountId': accountId,
        'spentOnPurpose': spentOnPurpose,
        'divertedAmount': divertedAmount,
        'reimbursedAmount': reimbursedAmount,
        'closedAt': closedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ThirdPartyFund.fromJson(Map<String, dynamic> j) => ThirdPartyFund(
        id: j['id'] as String,
        title: j['title'] as String,
        owner: j['owner'] as String,
        initialAmount: (j['initialAmount'] as num).toInt(),
        purpose: j['purpose'] as String,
        deadline: j['deadline'] == null
            ? null
            : DateTime.tryParse(j['deadline'] as String),
        status: (j['status'] as String?)?.toUpperCase() == 'SETTLED'
            ? FundStatus.settled
            : FundStatus.active,
        accountId: j['accountId'] as String,
        spentOnPurpose: (j['spentOnPurpose'] as num?)?.toInt() ?? 0,
        divertedAmount: (j['divertedAmount'] as num?)?.toInt() ?? 0,
        reimbursedAmount: (j['reimbursedAmount'] as num?)?.toInt() ?? 0,
        closedAt: j['closedAt'] == null
            ? null
            : DateTime.tryParse(j['closedAt'] as String),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Achats planifiés (cagnottes)
// ---------------------------------------------------------------------------

class Purchase {
  final String id;
  final String title;
  final int targetCost;
  final DateTime? deadline;
  final PurchaseStatus status;
  final String icon;
  final String color;
  final String accountId;
  final DateTime? closedAt;
  final DateTime createdAt;

  const Purchase({
    required this.id,
    required this.title,
    required this.targetCost,
    this.deadline,
    this.status = PurchaseStatus.active,
    this.icon = 'shopping-bag',
    this.color = '#0d9488',
    required this.accountId,
    this.closedAt,
    required this.createdAt,
  });

  Purchase copyWith({
    String? title,
    int? targetCost,
    DateTime? deadline,
    PurchaseStatus? status,
    String? icon,
    String? color,
    String? accountId,
    DateTime? closedAt,
    bool clearDeadline = false,
  }) =>
      Purchase(
        id: id,
        title: title ?? this.title,
        targetCost: targetCost ?? this.targetCost,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        status: status ?? this.status,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        accountId: accountId ?? this.accountId,
        closedAt: closedAt ?? this.closedAt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetCost': targetCost,
        'deadline': deadline?.toIso8601String(),
        'status': status.name.toUpperCase(),
        'icon': icon,
        'color': color,
        'accountId': accountId,
        'closedAt': closedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: j['id'] as String,
        title: j['title'] as String,
        targetCost: (j['targetCost'] as num).toInt(),
        deadline: j['deadline'] == null
            ? null
            : DateTime.tryParse(j['deadline'] as String),
        status: PurchaseStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == (j['status'] as String?)?.toUpperCase(),
          orElse: () => PurchaseStatus.active,
        ),
        icon: j['icon'] as String? ?? 'shopping-bag',
        color: j['color'] as String? ?? '#0d9488',
        accountId: j['accountId'] as String,
        closedAt: j['closedAt'] == null
            ? null
            : DateTime.tryParse(j['closedAt'] as String),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Vues calculées (agrégats prêts à afficher)
// ---------------------------------------------------------------------------

/// Vue d'une dette : soldes calculés + traçabilité des remboursements.
class DebtStat {
  final Debt debt;
  final int repaid;
  final int totalDue;
  final int remaining;
  final double progress; // 0..1
  final bool settled;
  final String? destinationAccountName;
  final List<DebtRepayment> repayments;

  const DebtStat({
    required this.debt,
    required this.repaid,
    required this.totalDue,
    required this.remaining,
    required this.progress,
    required this.settled,
    required this.destinationAccountName,
    required this.repayments,
  });
}

/// Vue d'un fonds tiers.
class FundStat {
  final ThirdPartyFund fund;
  final int balance;
  final int creance;
  final bool settled;

  const FundStat({
    required this.fund,
    required this.balance,
    required this.creance,
    required this.settled,
  });
}

/// Vue d'un achat planifié (cagnotte).
class PurchaseStat {
  final Purchase purchase;
  final int saved;
  final int contributionsCount;
  final double progress; // 0..1

  const PurchaseStat({
    required this.purchase,
    required this.saved,
    required this.contributionsCount,
    required this.progress,
  });

  int get remaining => purchase.targetCost - saved;
}
