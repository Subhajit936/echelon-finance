import 'dart:convert';
import '../../data/models/transaction.dart';
import 'package:uuid/uuid.dart';

class TransactionParser {
  static const _uuid = Uuid();

  /// Extracts a <transaction>...</transaction> JSON block from Claude's response.
  /// Returns null if no valid block is found.
  static AppTransaction? tryParse(String response, String currency) {
    final regex = RegExp(r'<transaction>([\s\S]*?)<\/transaction>', caseSensitive: false);
    final match = regex.firstMatch(response);
    if (match == null) return null;

    try {
      final json = jsonDecode(match.group(1)!.trim()) as Map<String, dynamic>;

      final category = TransactionCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String? ?? 'other'),
        orElse: () => TransactionCategory.other,
      );

      final type = (json['type'] as String? ?? 'expense') == 'income'
          ? TransactionType.income
          : TransactionType.expense;

      final status = TransactionStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'cleared'),
        orElse: () => TransactionStatus.cleared,
      );

      DateTime date;
      try {
        date = DateTime.parse(json['date'] as String? ?? '');
      } catch (_) {
        date = DateTime.now();
      }

      return AppTransaction(
        id: _uuid.v4(),
        merchant: json['merchant'] as String? ?? 'Unknown',
        category: category,
        type: type,
        amount: (json['amount'] as num).toDouble(),
        date: date,
        status: status,
        note: json['note'] as String?,
        currency: currency,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Strips the <transaction> block from response for display text.
  static String stripTransactionBlock(String response) {
    return response
        .replaceAll(RegExp(r'<transaction>[\s\S]*?<\/transaction>', caseSensitive: false), '')
        .trim();
  }
}
