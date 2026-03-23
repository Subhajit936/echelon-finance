import 'package:flutter_test/flutter_test.dart';
import 'package:echelon_finance/core/utils/offline_responder.dart';

void main() {
  group('OfflineResponder', () {
    test('detects expense and returns confirmation with amount', () {
      final result = OfflineResponder.respond('Spent 450 on lunch', 'INR');
      expect(result.isTransaction, true);
      expect(result.amount, 450.0);
      expect(result.type, 'expense');
      expect(result.responseText, contains('₹450'));
    });

    test('detects expense with rupee symbol', () {
      final result = OfflineResponder.respond('Spent ₹850 at Zomato', 'INR');
      expect(result.isTransaction, true);
      expect(result.amount, 850.0);
      expect(result.merchant, isNotNull);
    });

    test('detects income message', () {
      final result = OfflineResponder.respond('Received 50000 salary', 'INR');
      expect(result.isTransaction, true);
      expect(result.amount, 50000.0);
      expect(result.type, 'income');
    });

    test('handles balance query without transaction', () {
      final result = OfflineResponder.respond('What is my balance', 'INR');
      expect(result.isTransaction, false);
      expect(result.responseText.toLowerCase(), contains('home'));
    });

    test('rejects off-topic message', () {
      final result = OfflineResponder.respond('Tell me a joke', 'INR');
      expect(result.isTransaction, false);
      expect(result.responseText, contains('financial'));
    });

    test('handles budget query', () {
      final result = OfflineResponder.respond('What is my budget', 'INR');
      expect(result.isTransaction, false);
      expect(result.responseText.toLowerCase(), contains('budget'));
    });

    test('USD currency uses dollar symbol', () {
      final result = OfflineResponder.respond('Spent 50 on lunch', 'USD');
      expect(result.responseText, contains('\$50'));
    });
  });
}
