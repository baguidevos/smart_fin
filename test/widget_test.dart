import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:samafi_mobile/core/constants.dart';
import 'package:samafi_mobile/core/format.dart';
import 'package:samafi_mobile/data/models.dart';
import 'package:samafi_mobile/data/repository.dart';
import 'package:samafi_mobile/modules/accounts/account_detail_view.dart';
import 'package:samafi_mobile/shared/widgets.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = await Directory.systemTemp.createTemp('samafi_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
    await GetStorage.init(FinanceRepository.storageName);
    await initializeDateFormatting('fr_FR');
  });

  group('SamaFi Core Tests', () {
    test('FCFA formatting test', () {
      final formatted = fcfa(50000);
      print('DEBUG FORMATTED: "$formatted"');
      expect(formatted.contains('50') && formatted.contains('FCFA'), isTrue);
    });

    test('AccountRole from name test', () {
      expect(roleFromName('WALLET'), AccountRole.wallet);
      expect(roleFromName('BUDGET'), AccountRole.budget);
      expect(roleFromName('SAVINGS'), AccountRole.savings);
      expect(roleFromName('UNKNOWN'), AccountRole.envelope);
    });

    test('Backup JSON v1.1.0 parsing and models test', () {
      const backupJson = '''
{
  "version": "1.1.0",
  "appName": "SmartFin",
  "data": {
    "profileName": "Mamadou Sow",
    "onboarded": true,
    "darkMode": true,
    "accounts": [
      {
        "id": "acc-1",
        "name": "Caisse Wave",
        "role": "WALLET",
        "balance": 150000,
        "createdAt": "2026-09-20T10:00:00.000Z"
      }
    ],
    "transactions": [
      {
        "id": "tx-1",
        "type": "INCOME",
        "amount": 150000,
        "label": "Virement Salaire",
        "date": "2026-09-20T10:00:00.000Z",
        "accountId": "acc-1",
        "createdAt": "2026-09-20T10:00:00.000Z"
      }
    ],
    "debts": [],
    "repayments": [],
    "tontines": [],
    "funds": [],
    "purchases": []
  }
}
''';
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
      expect(decoded['version'], '1.1.0');
      expect(decoded['appName'], 'SmartFin');
      final data = decoded['data'] as Map<String, dynamic>;
      expect(data['profileName'], 'Mamadou Sow');
      expect(data['onboarded'], isTrue);

      final account = Account.fromJson(data['accounts'][0] as Map<String, dynamic>);
      expect(account.id, 'acc-1');
      expect(account.name, 'Caisse Wave');
      expect(account.role, AccountRole.wallet);
      expect(account.balance, 150000);

      final tx = Transaction.fromJson(data['transactions'][0] as Map<String, dynamic>);
      expect(tx.amount, 150000);
      expect(tx.type, TxType.income);
      expect(tx.label, 'Virement Salaire');
    });

    test('Purchase copyWith and price modification test', () {
      final purchase = Purchase(
        id: 'p-1',
        title: 'Smartphone',
        targetCost: 150000,
        deadline: DateTime(2026, 12, 31),
        accountId: 'acc-cagnotte-1',
        createdAt: DateTime(2026, 9, 20),
      );

      expect(purchase.targetCost, 150000);
      expect(purchase.title, 'Smartphone');

      // Modifier le prix si le prix après ne correspond plus (ex: augmentation à 185 000 FCFA)
      final modifiedPrice = purchase.copyWith(targetCost: 185000);
      expect(modifiedPrice.targetCost, 185000);
      expect(modifiedPrice.title, 'Smartphone');
      expect(modifiedPrice.deadline, DateTime(2026, 12, 31));

      // Modifier le titre et effacer l'échéance
      final modifiedAll = purchase.copyWith(
        title: 'Smartphone Samsung S24',
        targetCost: 200000,
        clearDeadline: true,
      );
      expect(modifiedAll.title, 'Smartphone Samsung S24');
      expect(modifiedAll.targetCost, 200000);
      expect(modifiedAll.deadline, isNull);
    });

    test('Transaction copyWith test', () {
      final tx = Transaction(
        id: 'tx-1',
        type: TxType.expense,
        amount: 5000,
        label: 'Taxi',
        category: 'Transport',
        date: DateTime(2026, 9, 22),
        accountId: 'acc-1',
        createdAt: DateTime(2026, 9, 22),
      );

      final updated = tx.copyWith(amount: 7000);
      expect(updated.amount, 7000);
      expect(updated.label, 'Taxi');
      expect(updated.type, TxType.expense);
    });

    test('App version and changelog test', () {
      expect(kAppVersion, '1.2.3');
      expect(kChangelog.length, 7);
      expect(kChangelog.first.version, '1.2.3');
      expect(kChangelog.any((e) => e.version == '1.1.3'), isTrue);
      expect(kChangelog.any((e) => e.version == '1.1.2'), isTrue);
      expect(kChangelog.any((e) => e.version == '1.1.1'), isTrue);
      expect(kChangelog.any((e) => e.version == '1.1.0'), isTrue);
      expect(kChangelog.any((e) => e.version == '1.0.1'), isTrue);
      expect(kChangelog.any((e) => e.version == '1.0.0'), isTrue);
    });

    test('Envelope net allocation Golden Rule test (reallocation via transfer)', () {
      final repo = FinanceRepository();
      repo.resetAll();

      final wallet = repo.addAccount(name: 'Caisse', role: AccountRole.wallet, initialBalance: 50000);
      final envelope = repo.addAccount(name: 'Imprévus', role: AccountRole.envelope);

      // 1. Allocation initiale de 15 000 FCFA par virement entrant
      repo.transfer(amount: 15000, fromAccountId: wallet.id, toAccountId: envelope.id, label: 'Dotation');
      expect(repo.accountById(envelope.id)!.balance, 15000);

      var stats = repo.envelopeStats30j().firstWhere((e) => e.account.id == envelope.id);
      expect(stats.allocated, 15000);
      expect(stats.consumed, 0);

      // 2. Règle d'or : réallocation sortante de 10 000 FCFA vers un compte personnel
      repo.transfer(amount: 10000, fromAccountId: envelope.id, toAccountId: wallet.id, label: 'Réallocation');
      expect(repo.accountById(envelope.id)!.balance, 5000);

      stats = repo.envelopeStats30j().firstWhere((e) => e.account.id == envelope.id);
      // L'allocation nette est automatiquement ajustée à 5 000 FCFA
      expect(stats.allocated, 5000);
      expect(stats.consumed, 0);

      // 3. Dépense directe de 2 000 FCFA
      repo.addExpense(amount: 2000, label: 'Urgence', accountId: envelope.id, category: 'Santé');
      expect(repo.accountById(envelope.id)!.balance, 3000);

      stats = repo.envelopeStats30j().firstWhere((e) => e.account.id == envelope.id);
      expect(stats.allocated, 5000);
      expect(stats.consumed, 2000);
      // Parité comptable absolue : Solde = Alloué net - Consommé
      expect(stats.allocated - stats.consumed, repo.accountById(envelope.id)!.balance);
    });

    test('AccountDetailController full history and monthly stats test', () {
      final repo = FinanceRepository();
      repo.resetAll();
      Get.reset();
      Get.put<FinanceRepository>(repo);

      final account = repo.addAccount(
        name: 'Compte Courant',
        role: AccountRole.wallet,
        initialBalance: 100000,
      );

      // Dépense de 15 000 FCFA
      repo.addExpense(amount: 15000, label: 'Course supermarché', accountId: account.id, category: 'Alimentation');

      // Virement entrant de 30 000 FCFA depuis un autre compte
      final epargne = repo.addAccount(name: 'Épargne Test', role: AccountRole.savings, initialBalance: 50000);
      repo.transfer(amount: 30000, fromAccountId: epargne.id, toAccountId: account.id, label: 'Rapatriement');

      // Initialisation du contrôleur de détail de compte avec l'argument account.id
      final controller = AccountDetailController(accountId: account.id);

      expect(controller.account, isNotNull);
      expect(controller.account!.name, 'Compte Courant');

      // Vérification des transactions du compte
      final txs = controller.allTransactions;
      expect(txs.length, 3); // Solde initial + dépense + virement entrant

      // Vérification des totaux entrées / sorties
      expect(controller.totalInflow, 130000); // 100 000 (initial) + 30 000 (virement)
      expect(controller.totalOutflow, 15000); // 15 000 (dépense)

      // Vérification des statistiques mensuelles (6 derniers mois)
      final monthly = controller.monthlyStats;
      expect(monthly.length, 6);
      final currentMonthStat = monthly.last;
      expect(currentMonthStat.inflow, 130000);
      expect(currentMonthStat.outflow, 15000);
      expect(currentMonthStat.net, 115000);

      // Test du filtre par mois
      expect(controller.selectedMonthKey.value, isNull);
      controller.toggleMonthFilter(currentMonthStat.monthKey);
      expect(controller.selectedMonthKey.value, currentMonthStat.monthKey);
      expect(controller.displayedTransactions.length, 3);

      controller.clearFilter();
      expect(controller.selectedMonthKey.value, isNull);
    });

    test('Income, Expense and Transfer amount modification tests with FinanceRepository', () async {
      final repo = FinanceRepository();
      repo.resetAll();

      // Création de deux comptes
      final wallet = repo.addAccount(
        name: 'Portefeuille Test',
        role: AccountRole.wallet,
        initialBalance: 50000,
      );
      final savings = repo.addAccount(
        name: 'Caisse Épargne',
        role: AccountRole.savings,
        initialBalance: 20000,
      );

      expect(repo.accountById(wallet.id)!.balance, 50000);
      expect(repo.accountById(savings.id)!.balance, 20000);

      // --- 1. Test Encaissement & Modification montant ---
      repo.addIncome(
        totalAmount: 30000,
        label: 'Salaire Freelance',
        allocations: [
          Allocation(accountId: wallet.id, amount: 30000),
        ],
      );
      expect(repo.accountById(wallet.id)!.balance, 80000);

      final incomeTx = repo.transactions.firstWhere((t) => t.type == TxType.income);
      expect(incomeTx.amount, 30000);

      // Augmentation du montant de l'encaissement : 30 000 -> 45 000 (+15 000)
      repo.updateIncomeAmount(transactionId: incomeTx.id, newAmount: 45000);
      expect(repo.accountById(wallet.id)!.balance, 95000);
      expect(repo.transactionById(incomeTx.id)!.amount, 45000);

      // Diminution du montant de l'encaissement : 45 000 -> 35 000 (-10 000)
      repo.updateIncomeAmount(transactionId: incomeTx.id, newAmount: 35000);
      expect(repo.accountById(wallet.id)!.balance, 85000);
      expect(repo.transactionById(incomeTx.id)!.amount, 35000);

      // Diminution impossible si solde insuffisant (ex: retirer plus que le solde disponible)
      expect(
        () => repo.updateIncomeAmount(transactionId: incomeTx.id, newAmount: -1000),
        throwsA(isA<AppException>()),
      );

      // --- 2. Test Dépense & Modification montant ---
      repo.addExpense(
        amount: 20000,
        label: 'Abonnement Internet',
        accountId: wallet.id,
        category: 'Factures',
      );
      // wallet: 85000 - 20000 = 65000
      expect(repo.accountById(wallet.id)!.balance, 65000);

      final expenseTx = repo.transactions.firstWhere((t) => t.type == TxType.expense);
      expect(expenseTx.amount, 20000);

      // Augmentation de la dépense : 20 000 -> 30 000 (débit supplémentaire de 10 000)
      repo.updateExpenseAmount(transactionId: expenseTx.id, newAmount: 30000);
      expect(repo.accountById(wallet.id)!.balance, 55000);
      expect(repo.transactionById(expenseTx.id)!.amount, 30000);

      // Diminution de la dépense : 30 000 -> 10 000 (recrédit de 20 000)
      repo.updateExpenseAmount(transactionId: expenseTx.id, newAmount: 10000);
      expect(repo.accountById(wallet.id)!.balance, 75000);
      expect(repo.transactionById(expenseTx.id)!.amount, 10000);

      // --- 3. Test Virement & Modification montant ---
      repo.transfer(
        amount: 25000,
        fromAccountId: wallet.id,
        toAccountId: savings.id,
        label: 'Virement vers épargne',
      );
      // wallet: 75000 - 25000 = 50000 ; savings: 20000 + 25000 = 45000
      expect(repo.accountById(wallet.id)!.balance, 50000);
      expect(repo.accountById(savings.id)!.balance, 45000);

      final transferTx = repo.transactions.firstWhere((t) => t.type == TxType.transfer);
      expect(transferTx.amount, 25000);

      // Augmentation du virement : 25 000 -> 35 000 (+10 000 de wallet vers savings)
      repo.updateTransferAmount(transactionId: transferTx.id, newAmount: 35000);
      expect(repo.accountById(wallet.id)!.balance, 40000);
      expect(repo.accountById(savings.id)!.balance, 55000);
      expect(repo.transactionById(transferTx.id)!.amount, 35000);

      // Diminution du virement : 35 000 -> 15 000 (savings rend 20 000 à wallet)
      repo.updateTransferAmount(transactionId: transferTx.id, newAmount: 15000);
      expect(repo.accountById(wallet.id)!.balance, 60000);
      expect(repo.accountById(savings.id)!.balance, 35000);
      expect(repo.transactionById(transferTx.id)!.amount, 15000);

      // Impossible de diminuer le virement si le compte destination n'a plus assez
      expect(
        () => repo.updateTransferAmount(transactionId: transferTx.id, newAmount: -50000),
        throwsA(isA<AppException>()),
      );

      // --- 4. Test Dispatcher universel updateTransactionAmount ---
      // Modification dépense via updateTransactionAmount
      repo.updateTransactionAmount(transactionId: expenseTx.id, newAmount: 15000);
      expect(repo.accountById(wallet.id)!.balance, 55000); // 60000 - 5000 = 55000

      // Modification encaissement via updateTransactionAmount
      repo.updateTransactionAmount(transactionId: incomeTx.id, newAmount: 40000);
      expect(repo.accountById(wallet.id)!.balance, 60000); // 55000 + 5000 = 60000

      // Modification virement via updateTransactionAmount
      repo.updateTransactionAmount(transactionId: transferTx.id, newAmount: 20000);
      expect(repo.accountById(wallet.id)!.balance, 55000); // 60000 - 5000 = 55000
      expect(repo.accountById(savings.id)!.balance, 40000); // 35000 + 5000 = 40000
    });

    testWidgets('showEditTransactionAmountSheet modifies amount and closes cleanly without controller disposal error', (tester) async {
      final repo = FinanceRepository();
      repo.resetAll();
      Get.reset();
      Get.put<FinanceRepository>(repo);

      final wallet = repo.addAccount(
        name: 'Compte Test',
        role: AccountRole.wallet,
        initialBalance: 50000,
      );

      repo.addExpense(
        amount: 5000,
        label: 'Achat Test',
        accountId: wallet.id,
      );

      final tx = repo.transactions.firstWhere((t) => t.type == TxType.expense);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEditTransactionAmountSheet(context, tx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le montant de la dépense'), findsOneWidget);

      // Saisie du nouveau montant
      final amountFinder = find.byType(TextFormField);
      expect(amountFinder, findsOneWidget);
      await tester.enterText(amountFinder, '8000');
      await tester.pump();

      // Enregistrer
      await tester.tap(find.text('Enregistrer le nouveau montant'));
      await tester.pumpAndSettle();

      // Vérification : la feuille se ferme sans erreur de contrôleur disposed et les données sont à jour
      expect(find.text('Modifier le montant de la dépense'), findsNothing);
      expect(repo.transactionById(tx.id)!.amount, 8000);
      expect(repo.accountById(wallet.id)!.balance, 42000); // 50000 - 8000 = 42000
    });
  });
}

