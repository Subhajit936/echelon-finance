/// Handles AI Buddy responses locally when no API key is configured.
/// Pure keyword matching + regex — zero API calls, zero tokens burned.
class OfflineResponse {
  final String responseText;
  final bool isTransaction;
  final double? amount;
  final String? type; // 'expense' | 'income'
  final String? merchant;

  const OfflineResponse({
    required this.responseText,
    this.isTransaction = false,
    this.amount,
    this.type,
    this.merchant,
  });
}

class OfflineResponder {
  static final _amountRe = RegExp(
    r'(?:rs\.?|inr|₹|\$)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static const _expenseKeywords = [
    'spent', 'paid', 'bought', 'purchased', 'expense',
    'cost', 'charged', 'debited', 'withdrew', 'deducted',
  ];
  static const _incomeKeywords = [
    'received', 'earned', 'got', 'salary', 'income',
    'credited', 'deposited', 'payment received', 'freelance', 'transfer in',
  ];
  static const _balanceKeywords = ['balance', 'total', 'how much', 'summary', 'net worth'];
  static const _budgetKeywords = ['budget', 'limit', 'overspend', 'over budget'];
  static const _savingsKeywords = ['save', 'savings', 'goal', 'invest', 'target'];

  static OfflineResponse respond(String message, String currency) {
    final lower = message.toLowerCase().trim();
    final symbol = currency == 'INR' ? '₹' : '\$';

    // ── Expense ────────────────────────────────────────────────────────────
    if (_expenseKeywords.any((k) => lower.contains(k))) {
      final amount = _extractAmount(message);
      if (amount != null) {
        final merchant = _extractMerchant(message) ?? 'General';
        return OfflineResponse(
          responseText: 'Got it! Logged $symbol${amount.toStringAsFixed(0)} '
              'expense at $merchant ✓\n\n'
              '_Tip: Add a Claude or OpenAI key in Settings → AI Provider for smarter categorisation._',
          isTransaction: true,
          amount: amount,
          type: 'expense',
          merchant: merchant,
        );
      }
      return const OfflineResponse(
        responseText: 'Looks like an expense! How much did you spend, and where?\n'
            '_e.g. "Spent ₹450 at Zomato"_',
      );
    }

    // ── Income ─────────────────────────────────────────────────────────────
    if (_incomeKeywords.any((k) => lower.contains(k))) {
      final amount = _extractAmount(message);
      if (amount != null) {
        final merchant = _extractMerchant(message) ?? 'Income';
        return OfflineResponse(
          responseText: 'Logged $symbol${amount.toStringAsFixed(0)} income'
              ' from $merchant ✓',
          isTransaction: true,
          amount: amount,
          type: 'income',
          merchant: merchant,
        );
      }
      return const OfflineResponse(
        responseText: 'Income noted! What was the amount?\n'
            '_e.g. "Received ₹50,000 salary"_',
      );
    }

    // ── Balance / summary ──────────────────────────────────────────────────
    if (_balanceKeywords.any((k) => lower.contains(k))) {
      return const OfflineResponse(
        responseText: 'Your balance and net worth are on the **Home** screen.\n'
            'For a detailed breakdown, check **Insights**.\n\n'
            '_Add an API key in Settings for personalised AI analysis._',
      );
    }

    // ── Budget ─────────────────────────────────────────────────────────────
    if (_budgetKeywords.any((k) => lower.contains(k))) {
      return const OfflineResponse(
        responseText: 'Budget limits can be set in **Settings → Monthly Budgets**.\n'
            'Your current month\'s spend vs limits appears on the Home screen as coloured pills.',
      );
    }

    // ── Savings / goals ────────────────────────────────────────────────────
    if (_savingsKeywords.any((k) => lower.contains(k))) {
      return const OfflineResponse(
        responseText: 'Your savings goals live on the **Goals** screen.\n'
            'Tap any goal to contribute to it.\n\n'
            '_Add a Claude API key in Settings for AI-powered savings tips._',
      );
    }

    // ── Off-topic / unknown ────────────────────────────────────────────────
    return const OfflineResponse(
      responseText: 'I can only help with financial topics — logging expenses, '
          'income, budgets, and savings goals.\n\n'
          'Try:\n• _"Spent ₹300 on coffee"_\n• _"Received ₹50,000 salary"_\n\n'
          '_Add a Claude or OpenAI key in Settings for full AI responses._',
    );
  }

  static double? _extractAmount(String text) {
    final match = _amountRe.firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1)!.replaceAll(',', '');
    final val = double.tryParse(raw);
    return (val != null && val > 0) ? val : null;
  }

  static String? _extractMerchant(String text) {
    final atMatch = RegExp(r'\bat\s+([A-Za-z][A-Za-z0-9 ]{2,20})', caseSensitive: false).firstMatch(text);
    if (atMatch != null) return _cap(atMatch.group(1)!.trim());
    final forMatch = RegExp(r'\bfor\s+([A-Za-z][A-Za-z0-9 ]{2,20})', caseSensitive: false).firstMatch(text);
    if (forMatch != null) return _cap(forMatch.group(1)!.trim());
    final onMatch = RegExp(r'\bon\s+([A-Za-z][A-Za-z0-9 ]{2,20})', caseSensitive: false).firstMatch(text);
    if (onMatch != null) return _cap(onMatch.group(1)!.trim());
    return null;
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}
