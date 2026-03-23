import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/transaction.dart';

const _uuid = Uuid();

/// Result of parsing a single bank SMS.
class ParsedSmsTransaction {
  final String smsBody;
  final String sender;
  final AppTransaction transaction;
  bool isSelected;

  ParsedSmsTransaction({
    required this.smsBody,
    required this.sender,
    required this.transaction,
    this.isSelected = true,
  });
}

/// Reads device SMS inbox and parses bank transactions.
/// No AI is used here — pure regex extraction, saving API tokens.
class SmsService {
  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async => Permission.sms.isGranted;

  // ── SMS fetching ──────────────────────────────────────────────────────────

  /// Fetches and parses all SMS from the last [daysBack] days.
  Future<List<ParsedSmsTransaction>> fetchBankTransactions({
    int daysBack = 90,
    String currency = 'INR',
  }) async {
    final query = SmsQuery();
    final allMessages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 500,
    );

    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    final results = <ParsedSmsTransaction>[];

    for (final sms in allMessages) {
      final date = sms.date ?? DateTime.now();
      if (date.isBefore(cutoff)) continue;

      final body = sms.body ?? '';
      final sender = sms.sender ?? '';

      if (!isBankSms(body, sender)) continue;
      if (isSpamOrOtp(body)) continue;

      final parsed = parseTransactionPublic(body, date, currency);
      if (parsed != null) {
        results.add(ParsedSmsTransaction(
          smsBody: body,
          sender: sender,
          transaction: parsed,
        ));
      }
    }

    return results;
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  /// Returns true if the SMS looks like it came from a bank.
  bool isBankSms(String body, String sender) {
    final senderUpper = sender.toUpperCase();
    final bodyLower = body.toLowerCase();

    // Known Indian bank sender ID fragments
    const bankSenderFragments = [
      'HDFC', 'ICICI', 'SBIN', 'SBI', 'AXIS', 'KOTAK', 'PNB',
      'BOI', 'CANARA', 'UNION', 'IDFC', 'INDUS', 'YES', 'FEDERAL',
      'PAYTM', 'PHONEPE', 'GPAY', 'AMAZONPAY', 'MOBIKWIK', 'FREECHARGE',
      'RAZORPAY', 'NSDL', 'CITI', 'HSBC', 'STAN', 'BARODA', 'BOB',
    ];

    if (bankSenderFragments.any((f) => senderUpper.contains(f))) return true;

    // Fallback: SMS body contains key banking terms
    final bankKeywords = ['a/c', 'account', 'credited', 'debited', 'neft',
      'imps', 'upi', 'balance', 'avl bal', 'txn', 'ref no'];
    return bankKeywords.where((k) => bodyLower.contains(k)).length >= 2;
  }

  /// Returns true if the SMS is an OTP, spam, or marketing message.
  bool isSpamOrOtp(String body) {
    final lower = body.toLowerCase();

    // OTP patterns
    if (RegExp(r'\b(otp|one.?time.?password|mpin)\b').hasMatch(lower)) return true;
    if (RegExp(r'\bis\s+\d{4,8}\b').hasMatch(lower)) return true;
    if (RegExp(r'\bcode\s+is\s+\d{4,8}\b').hasMatch(lower)) return true;

    // Marketing / promotional
    if (RegExp(r'\b(offer|discount|win|prize|free|click here|'
        r'congratulation|pre-approved|loan offer|apply now)\b').hasMatch(lower)) {
      return true;
    }
    // Note: 'cashback' intentionally removed — legitimate bank credit

    // Very short messages are unlikely to be transaction alerts
    if (body.trim().length < 40) return true;

    return false;
  }

  // ── Parser ────────────────────────────────────────────────────────────────

  /// Public entry-point for the live SMS provider.
  AppTransaction? parseTransactionPublic(String body, DateTime date, String currency) =>
      _parseTransaction(body, date, currency);

  AppTransaction? _parseTransaction(String body, DateTime date, String currency) {
    final lower = body.toLowerCase();

    // ── Determine type: debit or credit ──
    final isDebit = RegExp(
      r'\b(debited|deducted|withdrawn|spent|payment of|sent|transferred out)\b',
    ).hasMatch(lower);
    final isCredit = RegExp(
      r'\b(credited|received|deposited|added|refund|cashback)\b',
    ).hasMatch(lower);

    if (!isDebit && !isCredit) return null;
    final type = isDebit ? TransactionType.expense : TransactionType.income;

    // ── Extract amount ──
    final amountPatterns = [
      // Rs.1,234.56 or INR 1234.56 or ₹1,234
      RegExp(r'(?:rs\.?|inr|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // 1,234.56 Rs
      RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)', caseSensitive: false),
      // USD / $ amounts
      RegExp(r'(?:usd|\$)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:usd|\$)', caseSensitive: false),
    ];

    double? amount;
    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final raw = match.group(1)!.replaceAll(',', '');
        amount = double.tryParse(raw);
        if (amount != null && amount > 0) break;
      }
    }
    if (amount == null) return null;

    // ── Extract merchant name ──
    final merchant = _extractMerchant(body, lower) ?? 'Bank Transfer';

    // ── Infer category ──
    final category = _inferCategory(lower, merchant.toLowerCase(), type);

    return AppTransaction(
      id: _uuid.v4(),
      merchant: merchant,
      category: category,
      type: type,
      amount: amount,
      date: date,
      status: TransactionStatus.cleared,
      note: 'Imported from SMS',
      currency: currency,
      createdAt: DateTime.now(),
    );
  }

  String? _extractMerchant(String body, String lower) {
    // UPI pattern: "at MERCHANT NAME" or "to MERCHANT"
    var match = RegExp(r'\bat\s+([A-Z][A-Za-z0-9 &\-_]{2,30})', caseSensitive: true).firstMatch(body);
    if (match != null) return _cleanMerchant(match.group(1)!);

    match = RegExp(r'\bto\s+([A-Z][A-Za-z0-9 &\-_]{2,30})', caseSensitive: true).firstMatch(body);
    if (match != null) return _cleanMerchant(match.group(1)!);

    // "for DESCRIPTION"
    match = RegExp(r'\bfor\s+([A-Za-z][A-Za-z0-9 &\-_]{2,30})', caseSensitive: true).firstMatch(body);
    if (match != null) return _cleanMerchant(match.group(1)!);

    return null;
  }

  String _cleanMerchant(String raw) {
    // Strip trailing filler words
    return raw.replaceAll(RegExp(r'\s+(on|via|ref|upi|neft|imps|using).*', caseSensitive: false), '').trim();
  }

  TransactionCategory _inferCategory(String lower, String merchant, TransactionType type) {
    if (type == TransactionType.income) {
      if (lower.contains('salary') || lower.contains('payroll')) return TransactionCategory.salary;
      if (lower.contains('freelance') || lower.contains('payment received')) return TransactionCategory.freelance;
      return TransactionCategory.other;
    }

    if (_matchesAny(lower, merchant, ['zomato', 'swiggy', 'restaurant', 'food', 'cafe', 'hotel', 'eat', 'pizza', 'burger', 'chicken'])) {
      return TransactionCategory.food;
    }
    if (_matchesAny(lower, merchant, ['uber', 'ola', 'rapido', 'metro', 'petrol', 'fuel', 'irctc', 'redbus', 'flight', 'makemytrip'])) {
      return TransactionCategory.transport;
    }
    if (_matchesAny(lower, merchant, ['amazon', 'flipkart', 'myntra', 'meesho', 'nykaa', 'shop', 'market', 'store'])) {
      return TransactionCategory.shopping;
    }
    if (_matchesAny(lower, merchant, ['netflix', 'hotstar', 'spotify', 'youtube', 'prime', 'game', 'cinema', 'pvr', 'inox'])) {
      return TransactionCategory.entertainment;
    }
    if (_matchesAny(lower, merchant, ['electricity', 'jio', 'airtel', 'vodafone', 'broadband', 'recharge', 'bill'])) {
      return TransactionCategory.utilities;
    }
    if (_matchesAny(lower, merchant, ['hospital', 'pharmacy', 'medicine', 'doctor', 'clinic', 'health', 'apollo'])) {
      return TransactionCategory.healthcare;
    }
    if (_matchesAny(lower, merchant, ['zerodha', 'groww', 'mutual fund', 'sip', 'nps', 'demat', 'stockbroker'])) {
      return TransactionCategory.investment;
    }
    if (_matchesAny(lower, merchant, ['rent', 'maintenance', 'housing', 'apartment', 'pg', 'hostel'])) {
      return TransactionCategory.housing;
    }
    if (_matchesAny(lower, merchant, ['school', 'college', 'course', 'fee', 'tuition', 'udemy', 'coursera'])) {
      return TransactionCategory.education;
    }

    return TransactionCategory.other;
  }

  bool _matchesAny(String lower, String merchant, List<String> keywords) =>
      keywords.any((k) => lower.contains(k) || merchant.contains(k));

  /// Public helper: infer category from a plain merchant name (used by offline AI Buddy).
  TransactionCategory inferCategoryFromMerchant(String merchant, TransactionType type) {
    final m = merchant.toLowerCase();
    return _inferCategory(m, m, type);
  }
}
