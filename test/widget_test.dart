import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:samafi_mobile/core/format.dart';
import 'package:samafi_mobile/data/models.dart';

void main() {
  setUpAll(() async {
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
  });
}
