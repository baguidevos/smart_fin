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
  });
}
